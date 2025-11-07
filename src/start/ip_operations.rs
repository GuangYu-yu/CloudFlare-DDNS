use anyhow::Result;
use std::fs;
use std::process::Command;
use std::time::Duration;
use super::dns_operations::DnsOperations;

pub trait IpOperations {
    /// 获取并过滤IP地址
    fn fetch_and_filter_ips(
        &self,
        url: &str,
        max_count: u32,
        ip_type: &str,
        output_file: Option<&str>,
    ) -> Result<Vec<String>>;

    /// 带重试的获取函数
    fn fetch_with_retry(
        &self,
        url: &str,
        max_retries: u32,
        retry_delay: Duration,
        ip_type: &str,
    ) -> Result<String>;

    /// 从CSV文件读取指定类型的IP地址
    fn read_ips_from_csv(ip_type: &str, num: u32, cf_command: &str) -> Result<Vec<String>>;

    /// 处理单个IP类型的完整流程
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

        #[cfg(target_os = "linux")]
        plugin_status: Option<&str>,

        #[cfg(target_os = "linux")]
        clien: &str,

    ) -> Result<(Vec<String>, std::collections::HashMap<String, Vec<String>>)>;
}

impl IpOperations for super::start_struct::Start {
    fn fetch_and_filter_ips(
        &self,
        url: &str,
        max_count: u32,
        ip_type: &str,
        output_file: Option<&str>,
    ) -> Result<Vec<String>> {
        crate::info_println(format_args!("获取{}地址...", ip_type));

        if url.is_empty() {
            crate::warning_println(format_args!("URL为空，跳过{}地址下载", ip_type));
            return Ok(Vec::new());
        }

        let max_retries = 5;
        let retry_delay = Duration::from_secs(2);

        let response_text = self.fetch_with_retry(url, max_retries, retry_delay, ip_type)?;

        // 过滤IP地址
        let mut filtered_ips: Vec<String> = response_text
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
        if filtered_ips.len() > max_count {
            filtered_ips.truncate(max_count);
        }

        // 如果指定了输出文件，则将结果保存到文件
        if let Some(file_path) = output_file {
            let content = filtered_ips.join("\n");
            std::fs::write(file_path, content)?;
            crate::info_println(format_args!("地址获取成功"));
        }

        Ok(filtered_ips)
    }

    fn fetch_with_retry(
        &self,
        url: &str,
        max_retries: u32,
        retry_delay: Duration,
        ip_type: &str,
    ) -> Result<String> {
        let mut attempt = 1;

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
                        return Ok(String::from_utf8_lossy(&output.stdout).to_string());
                    } else {
                        crate::warning_println(format_args!("获取{}地址失败, 重试 {} 次...", ip_type, attempt));
                    }
                }
                Err(e) => {
                    crate::warning_println(
                        format_args!(
                            "获取{}地址失败，错误: {}, 重试 {} 次...",
                            ip_type, e, attempt
                        )
                    );
                }
            }

            attempt += 1;
            std::thread::sleep(retry_delay);
        }

        Err(anyhow::anyhow!(
            "获取{}地址失败，已达到最大重试次数",
            ip_type
        ))
    }

    fn read_ips_from_csv(ip_type: &str, num: u32, cf_command: &str) -> Result<Vec<String>> {
        let result_csv_path = super::utils::get_result_csv_path(cf_command);
        if std::path::Path::new(&result_csv_path).exists() {
            let content = fs::read_to_string(&result_csv_path)?;

            Ok(content
                .lines()
                .skip(1) // 跳过标题行
                .filter_map(|line| {
                    let fields: Vec<&str> = line.split(',').collect();
                    fields.first().map(|&ip| ip.to_string())
                })
                .filter(|ip| {
                    let is_ipv4 = ip.contains('.');
                    ip_type.is_empty()
                        || (ip_type == "IPv4" && is_ipv4)
                        || (ip_type == "IPv6" && !is_ipv4)
                })
                .take(if num == 0 { usize::MAX } else { num as usize })
                .collect())
        } else {
            Ok(Vec::new())
        }
    }

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

        #[cfg(target_os = "linux")]
        plugin_status: Option<&str>,

        #[cfg(target_os = "linux")]
        clien: &str,

    ) -> Result<(Vec<String>, std::collections::HashMap<String, Vec<String>>)> {
        let mut ips = Vec::new();
        let mut domain_ip_map = std::collections::HashMap::new();
        let record_type = if ip_type.is_empty() {
            None
        } else if ip_type == "IPv4" {
            Some("A")
        } else {
            Some("AAAA")
        };

        // 下载IP地址
        if output_file.is_some() && !url.is_empty() {
            self.fetch_and_filter_ips(url, num, ip_type, output_file)?;
        }

        crate::print_section_header("运行测速程序");
        
        // 打印将要执行的命令
        #[cfg(target_os = "windows")]
        println!("[执行] .\\{} {}\n", crate::CLOUDFLAREST_RUST, cf_command);
        
        #[cfg(any(target_os = "linux", target_os = "macos"))]
        println!("[执行] ./{} {}\n", crate::CLOUDFLAREST_RUST, cf_command);

        // 执行测速
        #[cfg(target_os = "windows")]
        let mut cmd = Command::new(format!(".\\{}", crate::CLOUDFLAREST_RUST));

        #[cfg(any(target_os = "linux", target_os = "macos"))]
        let mut cmd = Command::new(format!("./{}", crate::CLOUDFLAREST_RUST));
        cmd.args(cf_command.split_whitespace());

        if num > 0 {
            let num_str = num.to_string();
            cmd.arg("-dn").arg(&num_str);
            cmd.arg("-p").arg(&num_str);
        }

        let status = cmd.status()?;
        if !status.success() {
            return Err(anyhow::anyhow!("{} 执行失败", crate::CLOUDFLAREST_RUST));
        }

        // 读取测速结果
        let result_csv_path = super::utils::get_result_csv_path(cf_command);
        if std::path::Path::new(&result_csv_path).exists() {
            let content = fs::read_to_string(&result_csv_path)?;

            ips = content
                .lines()
                .skip(1) // 跳过标题行
                .filter_map(|line| {
                    let fields: Vec<&str> = line.split(',').collect();
                    fields.first().map(|&ip| ip.to_string())
                })
                .filter(|ip| {
                    let is_ipv4 = ip.contains('.');
                    ip_type.is_empty()
                        || (ip_type == "IPv4" && is_ipv4)
                        || (ip_type == "IPv6" && !is_ipv4)
                })
                .take(if num == 0 { usize::MAX } else { num as usize })
                .collect();
        }

        // 处理DNS记录
        if add_ddns != "未指定" && !ips.is_empty() {
            // 验证Cloudflare账号
            super::cloudflare_api::CloudflareApi::validate_cloudflare_account(self, x_email, api_key, zone_id)?;

            // 重启插件
            #[cfg(target_os = "linux")]
            {
                if !clien.is_empty() && clien != "未指定" && plugin_status == Some("stopped") {
                    crate::print_section_header("插件重启");
                    crate::info_println(format_args!("正在重启插件 {}", clien));
                    let status = Command::new(format!("/etc/init.d/{}", clien))
                        .arg("restart")
                        .status()?;
                    if status.success() {
                        crate::info_println(format_args!("已重启插件 {}", clien));
                        std::thread::sleep(std::time::Duration::from_secs(10));
                    } else {
                        crate::error_println(format_args!("重启插件 {} 失败", clien));
                    }
                }
            }

            // 删除旧记录
            let mut records_to_delete = Vec::new();
            
            // 收集所有需要删除的记录
            for domain in domains {
                if ip_type.is_empty() {
                    // 当ip_type为空时，获取并删除所有类型的记录
                    let existing_records =
                        self.get_dns_records(x_email, api_key, zone_id, domain, None)?;
                    let exclude_set: std::collections::HashSet<_> = ips.iter().cloned().collect();
                    for record in &existing_records {
                        if !exclude_set.contains(&record.content) {
                            // 根据记录内容判断记录类型
                            let record_type = if record.content.contains('.') {
                                "A"
                            } else {
                                "AAAA"
                            };
                            records_to_delete.push((domain.to_string(), record.content.to_string(), record_type.to_string(), record.id.to_string()));
                        }
                    }
                } else {
                    // 当ip_type不为空时，只获取并删除对应类型的记录
                    let existing_records =
                        self.get_dns_records(x_email, api_key, zone_id, domain, record_type)?;
                    let exclude_set: std::collections::HashSet<_> = ips.iter().cloned().collect();
                    for record in &existing_records {
                        if !exclude_set.contains(&record.content) {
                            records_to_delete.push((domain.to_string(), record.content.to_string(), record_type.unwrap().to_string(), record.id.to_string()));
                        }
                    }
                }
            }

            // 统一的格式化函数，用于处理"→ -"和"→ +"的显示，实现自适应左对齐
            fn format_dns_operation(left: &str, arrow: &str, right: &str, max_left_width: usize) -> String {
                format!("{:<width$} {} {}", left, arrow, right, width = max_left_width)
            }
            
            // 创建域名和IP的映射关系
            let domain_ip_mapping = super::utils::create_domain_ip_mapping(&ips, &domains, add_ddns);

            let max_delete_width = records_to_delete.iter().map(|(d, _, _, _)| d.len()).max().unwrap_or(0);
            let max_add_width = domain_ip_mapping.iter().map(|(_, i)| i.len()).max().unwrap_or(0);

            // 如果有需要删除的记录，则显示删除节点章节标题并执行删除
            if !records_to_delete.is_empty() {
                crate::print_section_header("删除节点");
                crate::info_println(format_args!("开始删除 {} 个节点:", records_to_delete.len()));
                
                let mut delete_success_count = 0;
                for (domain, ip, _record_type, record_id) in records_to_delete {
                    if self.delete_dns_record(x_email, api_key, zone_id, &record_id)? {
                        // 在这里集中处理删除记录的格式化输出
                        print!("  "); // 缩进
                        let formatted_output = format_dns_operation(&domain, "→ -", &ip, max_delete_width);
                        crate::success_println(format_args!("{}", formatted_output));
                        delete_success_count += 1;
                    }
                }
                
                crate::info_println(format_args!("总共删除了 {} 个节点", delete_success_count));
            }

            // 打印添加节点章节标题
            crate::print_section_header("添加节点");
            crate::info_println(format_args!("开始添加 {} 个节点:", domain_ip_mapping.len()));

            let mut success_count = 0;
            for (domain, ip) in domain_ip_mapping {
                // 根据IP地址内容确定记录类型
                let record_type = if ip.contains('.') { "A" } else { "AAAA" };
                let res =
                    self.create_dns_record(x_email, api_key, zone_id, &domain, record_type, &ip)?;
                if res {
                    // 在这里集中处理添加记录的格式化输出
                    print!("  "); // 缩进
                    let formatted_output = format_dns_operation(&domain, "→ +", &ip, max_add_width);
                    crate::success_println(format_args!("{}", formatted_output));
                    success_count += 1;
                    domain_ip_map
                        .entry(domain)
                        .or_insert_with(Vec::new)
                        .push(ip);
                }
            }

            crate::info_println(format_args!("总共添加了 {} 个节点", success_count));
        }

        Ok((ips, domain_ip_map))
    }
}