use dialoguer::{theme::ColorfulTheme, Select};
use console::Term;
use anyhow::Result;
use std::path::PathBuf;
use std::fs;
use std::process::Command;
use serde::{Deserialize};
use serde_json::Value;
use std::time::Duration;
use crate::push::PushService;
use crate::{Config, Resolve, clear_screen};

pub struct Start {
    config_path: PathBuf,
    config: Config,
    theme: ColorfulTheme,
    term: Term,
}

#[derive(Debug, Deserialize)]
struct DnsRecord {
    id: String,
    content: String,
}

impl Start {
    pub fn new(config_path: PathBuf) -> Result<Self> {
        Ok(Start {
            config: Config::load(&config_path)?,
            config_path,
            theme: ColorfulTheme::default(),
            term: Term::stdout(),
        })
    }

    fn generate_informlog_content(&self, add_ddns: &str, domain_ip_map: &std::collections::HashMap<String, Vec<String>>) -> String {
        let mut informlog_content = String::new();
        
        if add_ddns != "未指定" {
            for (domain, ips) in domain_ip_map {
                informlog_content += &format!("{}={}\n", domain, ips.join(","));
            }
        } else {
            // 当add_ddns为未指定时，将所有IP合并到一行
            let all_ips: Vec<String> = domain_ip_map.values()
                .flatten()
                .cloned()
                .collect();
            if !all_ips.is_empty() {
                informlog_content = format!("未指定={}\n", all_ips.join(","));
            }
        }
        
        informlog_content
    }

    /// 执行消息推送的统一封装
    fn execute_push(&self, 
        push_mod: &str, 
        hostnames: &str, 
        v4_num: u32, 
        v6_num: u32, 
        ip_type: &str, 
        ddns_name: &str, 
        domain_ip_map: &std::collections::HashMap<String, Vec<String>>,
        add_ddns: &str,
    ) -> Result<()> {
        if !push_mod.is_empty() && push_mod != "不设置" {
            let informlog_content = self.generate_informlog_content(add_ddns, domain_ip_map);
            
            self.run_push(
                push_mod,
                hostnames,
                v4_num,
                v6_num,
                ip_type,
                "result.csv",
                ddns_name,
                &informlog_content,
            )?;
        }
        Ok(())
    }

    // 获取并过滤IP地址
    fn fetch_and_filter_ips(&self, url: &str, max_count: u32, ip_type: &str, output_file: Option<&str>) -> Result<Vec<String>> {
        println!("获取{}地址...", ip_type);
        
        if url.is_empty() {
            println!("URL为空，跳过{}地址下载", ip_type);
            return Ok(Vec::new());
        }
        
        let max_retries = 5;
        let retry_delay = Duration::from_secs(2);
        
        let mut attempt = 1;
        let mut response_text = String::new();
        
        while attempt <= max_retries {
            let output = Command::new("curl")
                .arg("-s")
                .arg("--max-time")
                .arg("3")
                .arg(url)
                .output();
                
            match output {
                Ok(output) => {
                    if output.status.success() {
                        response_text = String::from_utf8_lossy(&output.stdout).to_string();
                        break;
                    } else {
                        println!("获取{}地址失败, 重试 {} 次...", 
                                 ip_type, attempt);
                    }
                },
                Err(e) => {
                    println!("获取{}地址失败，错误: {}, 重试 {} 次...", 
                             ip_type, e, attempt);
                }
            }
            
            attempt += 1;
            std::thread::sleep(retry_delay);
        }
        
        if attempt > max_retries {
            return Err(anyhow::anyhow!("获取{}地址失败，已达到最大重试次数", ip_type));
        }
        
        // 过滤IP地址
        let filtered_ips: Vec<String> = response_text
            .lines()
            .map(|line| line.trim())
            .filter(|line| !line.is_empty())
            .filter(|line| {
                let is_ipv4 = line.contains(".");
                (ip_type == "IPv4" && is_ipv4) || (ip_type == "IPv6" && !is_ipv4)
            })
            .take(max_count as usize)
            .map(|line| line.to_string())
            .collect();
        
        // 选择前max_count个IP
        let max_count = max_count as usize;
        let mut filtered_ips = filtered_ips;
        if filtered_ips.len() > max_count {
            filtered_ips.truncate(max_count);
        }
        
        // 如果指定了输出文件，则将结果保存到文件
        if let Some(file_path) = output_file {
            let content = filtered_ips.join("\n");
            std::fs::write(file_path, content)?;
            println!("地址获取成功");
        }
        
        Ok(filtered_ips)
    }
    
    // 验证Cloudflare账户
    fn validate_cloudflare_account(&self, x_email: &str, api_key: &str, zone_id: &str) -> Result<()> {
        println!("开始验证 Cloudflare 账号...");
        
        let max_retries = 10;
        let retry_delay = Duration::from_secs(2);
        let timeout = Duration::from_secs(5);
        
        let url = format!("https://api.cloudflare.com/client/v4/zones/{}", zone_id);
        
        let mut attempt = 1;
        while attempt <= max_retries {
            println!("正在进行第 {} 次登录尝试...", attempt);
            
            let output = Command::new("curl")
                .arg("-s")
                .arg("--max-time")
                .arg(timeout.as_secs().to_string())
                .arg("-H")
                .arg(format!("X-Auth-Email: {}", x_email))
                .arg("-H")
                .arg(format!("X-Auth-Key: {}", api_key))
                .arg("-H")
                .arg("Content-Type: application/json")
                .arg(&url)
                .output();
                
            match output {
                Ok(output) => {
                    println!("收到 Cloudflare 响应");
                    
                    if output.status.success() {
                        let response_text = String::from_utf8_lossy(&output.stdout);
                        let json: Value = serde_json::from_str(&response_text)?;
                        let success = json["success"].as_bool().unwrap_or(false);
                        
                        if success {
                            println!("Cloudflare 账号验证成功");
                            return Ok(());
                        } else {
                            let error_message = json["errors"][0]["message"].as_str().unwrap_or("未知错误");
                            println!("第 {} / {} 次登录失败", attempt, max_retries);
                            println!("错误信息: {}", error_message);
                        }
                    } else {
                        let stderr = String::from_utf8_lossy(&output.stderr);
                        println!("登录尝试失败，错误: {}", stderr);
                    }
                },
                
                Err(e) => {
                    println!("登录尝试失败，错误: {}", e);
                }
            }
            
            if attempt < max_retries {
                println!("等待 {} 秒后重试...", retry_delay.as_secs());
                std::thread::sleep(retry_delay);
            } else {
                return Err(anyhow::anyhow!("登录失败，已达到最大重试次数 {}", max_retries));
            }
            
            attempt += 1;
        }
        
        Err(anyhow::anyhow!("验证 Cloudflare 账号失败"))
    }
    
    // 获取DNS记录
    fn get_dns_records(&self, x_email: &str, api_key: &str, zone_id: &str, domain: &str, record_type: Option<&str>) -> Result<Vec<DnsRecord>> {
        let url = if let Some(rt) = record_type {
            format!(
                "https://api.cloudflare.com/client/v4/zones/{}/dns_records?type={}&name={}"
                , zone_id, rt, domain
            )
        } else {
            format!(
                "https://api.cloudflare.com/client/v4/zones/{}/dns_records?name={}"
                , zone_id, domain
            )
        };
        
        let output = Command::new("curl")
            .arg("-s")
            .arg("-H")
            .arg(format!("X-Auth-Email: {}", x_email))
            .arg("-H")
            .arg(format!("X-Auth-Key: {}", api_key))
            .arg("-H")
            .arg("Content-Type: application/json")
            .arg(&url)
            .output()?;
            
        if !output.status.success() {
            let stderr = String::from_utf8_lossy(&output.stderr);
            return Err(anyhow::anyhow!("获取DNS记录失败: {}", stderr));
        }
        
        let response_text = String::from_utf8_lossy(&output.stdout);
        let json: Value = serde_json::from_str(&response_text)?;
        let success = json["success"].as_bool().unwrap_or(false);
        
        if !success {
            let error_message = json["errors"][0]["message"].as_str().unwrap_or("未知错误");
            return Err(anyhow::anyhow!("获取DNS记录失败: {}", error_message));
        }
        
        let mut records = Vec::new();
        let result = &json["result"];
        
        if let Some(array) = result.as_array() {
            for item in array {
                let id = item["id"].as_str().unwrap_or("").to_string();
                let content = item["content"].as_str().unwrap_or("").to_string();
                
                records.push(DnsRecord { id, content });
            }
        }
        
        Ok(records)
    }
    
    // 解析 cf_command 获取 -f 参数指定的文件路径
    fn parse_cf_command_for_output_file(cf_command: &str) -> Option<String> {
        let args: Vec<&str> = cf_command.split_whitespace().collect();
        let mut i = 0;
        while i < args.len() {
            if args[i] == "-f" && i + 1 < args.len() {
                return Some(args[i + 1].to_string());
            }
            i += 1;
        }
        None
    }
    
    // 删除DNS记录
    fn delete_dns_record(&self, x_email: &str, api_key: &str, zone_id: &str, record_type: &str, record_id: &str) -> Result<()> {
        println!("删除旧 {} 记录...", record_type);
        
        let url = format!(
            "https://api.cloudflare.com/client/v4/zones/{}/dns_records/{}",
            zone_id, record_id
        );
        
        let output = Command::new("curl")
            .arg("-s")
            .arg("-X")
            .arg("DELETE")
            .arg("-H")
            .arg(format!("X-Auth-Email: {}", x_email))
            .arg("-H")
            .arg(format!("X-Auth-Key: {}", api_key))
            .arg("-H")
            .arg("Content-Type: application/json")
            .arg(&url)
            .output();
            
        let output = match output {
            Ok(out) => out,
            Err(e) => {
                eprintln!("删除DNS记录失败: {}", e);
                return Ok(());
            }
        };
        
        if !output.status.success() {
            let stderr = String::from_utf8_lossy(&output.stderr);
            eprintln!("删除DNS记录失败: {}", stderr);
            return Ok(());
        }
        
        let response_text = String::from_utf8_lossy(&output.stdout);
        let json: Value = match serde_json::from_str(&response_text) {
            Ok(j) => j,
            Err(e) => {
                eprintln!("解析响应JSON失败: {}", e);
                return Ok(());
            }
        };
        
        let success = json["success"].as_bool().unwrap_or(false);
        
        if success {
            println!("成功删除DNS记录");
        } else {
            let error_message = json["errors"][0]["message"].as_str().unwrap_or("未知错误");
            eprintln!("删除DNS记录失败: {}", error_message);
        }
        
        Ok(())
    }
    
    // 创建DNS记录
    fn create_dns_record(&self, x_email: &str, api_key: &str, zone_id: &str, domain: &str, record_type: &str, ip: &str) -> Result<bool> {
        println!("添加 {} 到 {}...", ip, domain);
        
        let url = format!(
            "https://api.cloudflare.com/client/v4/zones/{}/dns_records",
            zone_id
        );
        
        let proxy = false; // 默认关闭Cloudflare代理
        
        let body = serde_json::json!({
            "type": record_type,
            "name": domain,
            "content": ip,
            "proxied": proxy
        });
        
        let output = Command::new("curl")
            .arg("-s")
            .arg("-X")
            .arg("POST")
            .arg("-H")
            .arg(format!("X-Auth-Email: {}", x_email))
            .arg("-H")
            .arg(format!("X-Auth-Key: {}", api_key))
            .arg("-H")
            .arg("Content-Type: application/json")
            .arg("-d")
            .arg(body.to_string())
            .arg(&url)
            .output();
            
        let output = match output {
            Ok(out) => out,
            Err(e) => {
                eprintln!("创建DNS记录失败: {}", e);
                return Ok(false);
            }
        };
        
        if !output.status.success() {
            let stderr = String::from_utf8_lossy(&output.stderr);
            eprintln!("创建DNS记录失败: {}", stderr);
            return Ok(false);
        }
        
        let response_text = String::from_utf8_lossy(&output.stdout);
        let json: Value = match serde_json::from_str(&response_text) {
            Ok(j) => j,
            Err(e) => {
                eprintln!("解析响应JSON失败: {}", e);
                return Ok(false);
            }
        };
        
        let success = json["success"].as_bool().unwrap_or(false);
        
        if success {
            println!("成功添加 {}", ip);
            return Ok(true);
        } else {
            let code = json["errors"][0]["code"].as_i64().unwrap_or(0);
            let error_message = json["errors"][0]["message"].as_str().unwrap_or("未知错误");
            
            // 如果出现错误代码 81057，表示已有相同记录，不需要更新
            if code == 81057 {
                println!("已有 [{}] IP 记录，不做更新", ip);
                return Ok(false);
            } else {
                println!("添加 {} 到 {} 失败", ip, domain);
                println!("错误代码: {}", code);
                println!("错误信息: {}", error_message);
                return Ok(false);
            }
        }
    }

    pub fn run(&mut self, ddns_name: Option<String>) -> Result<()> {
        if let Some(name) = ddns_name {
            // 直接执行指定解析组
            self.execute_resolve_by_name(&name)?;
            return Ok(());
        }

        // 交互模式
        loop {
            clear_screen()?;

            let resolves = self.get_resolves()?;
            if resolves.is_empty() {
                println!("未找到任何解析配置");
                self.term.read_key()?;
                break;
            }

            let items: Vec<String> = resolves.iter().map(|r| format!("{}", r.ddns_name)).collect();
            let items_ref: Vec<&str> = items.iter().map(|s| s.as_str()).collect();

            let selection = Select::with_theme(&self.theme)
                .with_prompt("请选择解析组（按ESC返回上级）")
                .items(&items_ref)
                .default(0)
                .interact_opt()?;

            // 如果用户按ESC返回，则直接返回
            let selection = match selection {
                Some(value) => value,
                None => return Ok(()),
            };

            if selection < resolves.len() {
                let resolve = &resolves[selection];
                self.execute_resolve(resolve)?;
            }

            break;
        }

        Ok(())
    }

    fn get_resolves(&self) -> Result<Vec<Resolve>> {
        let resolves = self.config.resolve.as_ref()
            .map(|v| v.clone())
            .unwrap_or_default();
        Ok(resolves)
    }

    fn execute_resolve_by_name(&mut self, ddns_name: &str) -> Result<()> {
        let resolves = self.get_resolves()?;
        let resolve = resolves.iter()
            .find(|r| r.ddns_name == ddns_name)
            .ok_or_else(|| anyhow::anyhow!("未找到指定的解析组: {}", ddns_name))?;

        self.execute_resolve(resolve)?;
        Ok(())
    }

    fn execute_resolve(&self, resolve: &Resolve) -> Result<()> {
        
        // 获取账户信息
        let (x_email, zone_id, api_key) = if resolve.add_ddns != "未指定" {
            let account = self.config.account.iter()
                .find(|a| a.account_name == resolve.add_ddns)
                .ok_or_else(|| anyhow::anyhow!("未找到指定的账户: {}", resolve.add_ddns))?;
            (&account.x_email, &account.zone_id, &account.api_key)
        } else {
            (&String::new(), &String::new(), &String::new())
        };

        // 获取插件配置
        let default_clien = "未指定".to_string();
        let clien = self.config.plugin.as_ref()
            .map(|p| &p.clien)
            .unwrap_or(&default_clien);

        // 直接执行DDNS更新逻辑
        self.run_start_ddns(
            &resolve.add_ddns,
            &resolve.ddns_name,
            x_email,
            zone_id,
            api_key,
            &resolve.hostname1,
            &resolve.hostname2,
            resolve.v4_num,
            resolve.v6_num,
            &resolve.cf_command,
            &resolve.v4_url,
            &resolve.v6_url,
            &resolve.push_mod,
            clien,
        )?;

        Ok(())
    }

    // 处理单个IP类型的完整流程
    fn process_ip_type(
        &self,
        ip_type: &str,
        url: &str,
        num: u32,
        cf_command: &str,
        add_ddns: &str,
        x_email: &str,
        zone_id: &str,
        api_key: &str,
        domains: &[String],
        output_file: Option<&str>,
        plugin_status: Option<&str>,
        clien: &str,
    ) -> Result<(Vec<String>, std::collections::HashMap<String, Vec<String>>)> {
        let mut ips = Vec::new();
        let mut domain_ip_map = std::collections::HashMap::new();
        let record_type = if ip_type.is_empty() { None } else if ip_type == "IPv4" { Some("A") } else { Some("AAAA") };
        
        // 下载IP地址
        if output_file.is_some() && !url.is_empty() {
            self.fetch_and_filter_ips(url, num, ip_type, output_file)?;
        }
        
        // 执行测速
        let mut cmd = Command::new("./CloudflareST-Rust");
        cmd.args(cf_command.split_whitespace());
            
        if num > 0 {
            let num_str = num.to_string();
            cmd.arg("-dn").arg(&num_str);
            cmd.arg("-p").arg(&num_str);
        }
            
        let status = cmd.status()?;
        if !status.success() {
            return Err(anyhow::anyhow!("CloudflareST-Rust 执行失败"));
        }
        
        // 读取测速结果
        if std::path::Path::new("result.csv").exists() {
            let content = fs::read_to_string("result.csv")?;
            let lines: Vec<&str> = content.lines().collect();
            
            if lines.len() > 1 {
                // 跳过标题行，读取结果
                for line in lines.iter().skip(1) {
                    let fields: Vec<&str> = line.split(',').collect();
                    if fields.len() >= 1 {
                        let ip = fields[0].to_string();
                        let is_ipv4 = ip.contains('.');
                        
                        if ip_type.is_empty() || (ip_type == "IPv4" && is_ipv4) || (ip_type == "IPv6" && !is_ipv4) {
                            if num == 0 || ips.len() < num as usize {
                                ips.push(ip);
                            }
                        }
                    }
                }
            }
        }
        
        // 处理DNS记录
        if add_ddns != "未指定" && !ips.is_empty() {
            // 验证Cloudflare账号
            self.validate_cloudflare_account(x_email, api_key, zone_id)?;
            
            // 重启插件
            if !clien.is_empty() && clien != "未指定" && plugin_status == Some("stopped") {
                println!("正在重启插件 {}", clien);
                let status = Command::new(format!("/etc/init.d/{}", clien))
                    .arg("restart")
                    .status()?;
                if status.success() {
                    println!("已重启插件 {}", clien);
                    std::thread::sleep(std::time::Duration::from_secs(10));
                } else {
                    eprintln!("重启插件 {} 失败", clien);
                }
            }
            
            // 删除旧记录
            for domain in domains {
                if ip_type.is_empty() {
                    // 当ip_type为空时，获取并删除所有类型的记录
                    let existing_records = self.get_dns_records(x_email, api_key, zone_id, domain, None)?;
                    let exclude_set: std::collections::HashSet<_> = ips.iter().cloned().collect();
                    for record in &existing_records {
                        if !exclude_set.contains(&record.content) {
                            // 根据记录内容判断记录类型
                            let record_type = if record.content.contains('.') { "A" } else { "AAAA" };
                            let _ = self.delete_dns_record(x_email, api_key, zone_id, record_type, &record.id);
                        }
                    }
                } else {
                    // 当ip_type不为空时，只获取并删除对应类型的记录
                    let existing_records = self.get_dns_records(x_email, api_key, zone_id, domain, record_type)?;
                    let exclude_set: std::collections::HashSet<_> = ips.iter().cloned().collect();
                    for record in &existing_records {
                        if !exclude_set.contains(&record.content) {
                            let _ = self.delete_dns_record(x_email, api_key, zone_id, record_type.unwrap(), &record.id);
                        }
                    }
                }
            }
            
            // 添加新记录
            let domain_count = domains.len();
            let ip_count = ips.len();
            let mut ip_index = 0;
            let mut domain_index = 0;
            
            while ip_index < ip_count {
                let current_domain = &domains[domain_index];
                let current_ip = &ips[ip_index];
                
                // 根据IP地址内容确定记录类型
                let record_type = if current_ip.contains('.') { "A" } else { "AAAA" };
                let res = self.create_dns_record(x_email, api_key, zone_id, current_domain, record_type, current_ip)?;
                if res {
                    domain_ip_map.entry(current_domain.clone()).or_insert_with(Vec::new).push(current_ip.clone());
                }
                
                ip_index += 1;
                domain_index += 1;
                
                if domain_index >= domain_count {
                    domain_index = 0;
                }
            }
        }
        
        Ok((ips, domain_ip_map))
    }
    
    fn run_start_ddns(
        &self,
        add_ddns: &str,
        ddns_name: &str,
        x_email: &str,
        zone_id: &str,
        api_key: &str,
        hostname1: &str,
        hostname2: &str,
        v4_num: u32,
        v6_num: u32,
        cf_command: &str,
        v4_url: &str,
        v6_url: &str,
        push_mod: &str,
        clien: &str,
    ) -> Result<()> {

        if v4_num == 0 && v6_num == 0 {
            println!("IPv4和IPv6所需数量不能同时设为0");
            std::process::exit(0);

        }

        // ========== 构造域名 ==========

        let mut domains = Vec::new();
        let hostnames = if add_ddns != "未指定" {
            for sub in hostname2.split_whitespace() {
                let full = format!("{}.{}", sub, hostname1);
                domains.push(full.clone());
            }
            domains.join(" ")
        } else {
            String::new()
        };

        // ========== 插件控制：停止 ==========
        let plugin_status = if clien != "未指定" && !clien.is_empty() {
            println!("正在停止插件 {}", clien);
            let status = Command::new(format!("/etc/init.d/{}", clien))
                .arg("stop")
                .status()?;
            if status.success() { 
                println!("已停止插件 {}", clien);
                Some("stopped") 
            } else { 
                eprintln!("停止插件 {} 失败", clien);
                None 
            }
        } else {
            println!("按配置不停止插件");
            None
        };

        // 解析 cf_command 获取 -f 参数指定的文件路径
        let output_file = Self::parse_cf_command_for_output_file(cf_command);
        
        let mut all_domain_ip_map = std::collections::HashMap::new();
//        let mut has_update = false;
        
        let process_ip = |ip_type: &str, url: &str, num: u32| -> Result<(Vec<String>, std::collections::HashMap<String, Vec<String>>)> {
            self.process_ip_type(
                ip_type,
                url,
                num,
                cf_command,
                add_ddns,
                x_email,
                zone_id,
                api_key,
                &domains,
                output_file.as_ref().map(|f| f.as_str()),
                plugin_status.as_deref(),
                clien,
            )
        };

        // 处理IPv4
        if v4_num > 0 {
            let (v4_ips, v4_domain_ip_map) = process_ip("IPv4", v4_url, v4_num)?;
            
            if !v4_ips.is_empty() {
//                has_update = true;
                all_domain_ip_map.extend(v4_domain_ip_map);
                
                // IPv4消息推送
                self.execute_push(push_mod, &hostnames, v4_num, v6_num, "IPv4", ddns_name, &all_domain_ip_map, add_ddns)?;
            }
        } else {
            println!("根据设置，跳过 IPv4 测速");
        }
        
        // 处理IPv6
        if v6_num > 0 {
            let (v6_ips, v6_domain_ip_map) = process_ip("IPv6", v6_url, v6_num)?;
            
            if !v6_ips.is_empty() {
//                has_update = true;
                all_domain_ip_map.extend(v6_domain_ip_map);
                
                // IPv6消息推送
                self.execute_push(push_mod, &hostnames, v4_num, v6_num, "IPv6", ddns_name, &all_domain_ip_map, add_ddns)?;
            }
        } else {
            println!("根据设置，跳过 IPv6 测速");
        }
        
/*
        // 当v4_num和v6_num都为0时，直接测速、处理DNS、推送
        if v4_num == 0 && v6_num == 0 {
            let (ips, domain_ip_map) = process_ip("", "", 0)?;
            
            if !ips.is_empty() {
                has_update = true;
                all_domain_ip_map.extend(domain_ip_map);
            }
            
            // 综合消息推送
            if has_update {
                self.execute_push(push_mod, &hostnames, v4_num, v6_num, "IP", ddns_name, &all_domain_ip_map, add_ddns)?;
            }
        }
*/

        // ========== 插件控制：恢复 ==========

        if clien != "未指定" && !clien.is_empty() {
            if let Some("stopped") = plugin_status {
                println!("正在恢复插件 {}", clien);
                let status = Command::new(format!("/etc/init.d/{}", clien))
                    .arg("start")
                    .status();
                if status.is_ok() && status.unwrap().success() {
                    println!("已恢复插件 {}", clien);
                } else {
                    eprintln!("恢复插件 {} 失败", clien);
                }
            }
        }

        // 退出程序
        std::process::exit(0);
    }

    fn run_push(
        &self,
        push_mod: &str,
        hostnames: &str,
        v4_num: u32,
        v6_num: u32,
        ip_type: &str,
        csvfile: &str,
        ddns_name: &str,
        informlog_content: &str,
    ) -> Result<()> {

        let push_service = PushService::new(self.config_path.clone())?;
        push_service.run_push(
            push_mod,
            hostnames,
            v4_num,
            v6_num,
            ip_type,
            csvfile,
            ddns_name,
            informlog_content,
        )?;

        Ok(())
    }
}