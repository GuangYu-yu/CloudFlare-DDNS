use crate::{Config, GithubPushConfig, Settings, impl_settings};
use anyhow::Result;
use base64::{Engine as _, engine::general_purpose};
use serde_json::Value;
use std::fs;
use std::path::PathBuf;
use std::process::Command;

pub struct PushService {
    config_path: PathBuf,
    config: Config,
}

impl PushService {
    pub fn new(config_path: PathBuf) -> Result<Self> {
        let mut settings = PushService {
            config_path: config_path.clone(),
            config: Config::default(),
        };
        settings.load_config()?;
        Ok(settings)
    }

    pub fn run_push(
        &self,
        push_mod: &str,
        hostnames: &str,
        v4_num: u32,
        v6_num: u32,
        ip_type: &str,
        csvfile: &str,
        ddns_name: &str,
        domain_ip_mapping: &[(String, String)],
    ) -> Result<()> {
        // 检查是否设置了推送模式
        let push_modes: Vec<&str> = push_mod.split_whitespace().collect();
        let has_valid_push_mode = push_modes.iter().any(|&mode| mode != "不设置");

        if has_valid_push_mode {
            println!("正在执行推送任务...");
        } else {
            println!("根据配置跳过推送");
        }

        // 检查是否有更新信息
        if domain_ip_mapping.is_empty() {
            println!("没有更新信息，跳过推送");
            return Ok(());
        }

        // 读取 csvfile 内容
        let ip_info = self.process_csv_file(csvfile, hostnames, v4_num, v6_num, ip_type)?;

        // 处理多个推送模式
        for mode in push_modes {
            match mode {
                "Telegram" => {
                    self.push_telegram(&ip_info)?;
                }
                "PushPlus" => {
                    self.push_pushplus(&ip_info)?;
                }
                "Server酱" => {
                    self.push_server_chan(&ip_info)?;
                }
                "PushDeer" => {
                    self.push_pushdeer(&ip_info)?;
                }
                "企业微信" => {
                    self.push_wechat_work(&ip_info)?;
                }
                "Synology-Chat" => {
                    self.push_synology_chat(&ip_info)?;
                }
                "Github" => {
                    self.push_github(ddns_name, domain_ip_mapping)?;
                }
                _ => {
                    println!("未知的推送模式: {}", mode);
                }
            }
        }

        if has_valid_push_mode {
            println!("推送任务完成!");
        }
        Ok(())
    }

    fn process_csv_file(
        &self,
        csvfile: &str,
        hostnames: &str,
        v4_num: u32,
        v6_num: u32,
        ip_type: &str,
    ) -> Result<String> {
        if !std::path::Path::new(csvfile).exists() {
            return Ok(format!("错误: 没有测速结果 ({} 文件不存在)", csvfile));
        }

        let content = fs::read_to_string(csvfile)?;
        let lines: Vec<&str> = content.lines().collect();

        if lines.len() <= 1 {
            return Ok("错误: CSV文件为空或只有标题".to_string());
        }

        let ip_count = if ip_type == "IPv4" { v4_num } else { v6_num };

        // 解析域名
        let domain_arr: Vec<&str> = hostnames.split_whitespace().collect();

        let mut result = String::new();
        result.push_str(&format!("{} 地址：\n", ip_type));

        // 获取IP地址、延迟、速度和数据中心信息
        let csv_data: Vec<Vec<String>> = lines
            .iter()
            .skip(1)
            .take(ip_count as usize)
            .map(|line| line.split(',').map(|s| s.to_string()).collect::<Vec<_>>())
            .filter(|fields| fields.len() >= 7)
            .collect();

        let ips: Vec<String> = csv_data.iter().map(|fields| fields[0].clone()).collect();

        let latency: Vec<String> = csv_data
            .iter()
            .map(|fields| format!("{} ms", fields[4]))
            .collect();

        let speed: Vec<String> = csv_data
            .iter()
            .filter_map(|fields| {
                let speed_val = fields[5].trim();
                if !speed_val.is_empty() {
                    Some(format!("{} MB/s", speed_val))
                } else {
                    None
                }
            })
            .collect();

        let datacenter: Vec<String> = csv_data.iter().map(|fields| fields[6].clone()).collect();

        // 输出IP地址
        for ip in &ips {
            result.push_str(&format!("{}\n", ip));
        }

        result.push_str("━━━━━━━━━━━━━━━━━━━\n");
        result.push_str("域名：\n");

        // 输出域名
        for (i, domain) in domain_arr.iter().enumerate() {
            if i < ips.len() {
                result.push_str(&format!("{}\n", domain));
            }
        }

        result.push_str("━━━━━━━━━━━━━━━━━━━\n");
        result.push_str("平均延迟：\n");

        // 输出延迟
        for l in &latency {
            result.push_str(&format!("{}\n", l));
        }

        result.push_str("━━━━━━━━━━━━━━━━━━━\n");
        result.push_str("下载速度：\n");

        // 输出速度
        for s in &speed {
            result.push_str(&format!("{}\n", s));
        }

        result.push_str("━━━━━━━━━━━━━━━━━━━\n");
        result.push_str("数据中心：\n");

        // 输出数据中心
        for d in &datacenter {
            result.push_str(&format!("{}\n", d));
        }

        Ok(result)
    }

    fn curl_post_json(
        &self,
        url: &str,
        json_data: &str,
        headers: &[&str],
        timeout: u64,
    ) -> Result<(bool, String)> {
        let mut cmd = Command::new("curl");
        cmd.arg("-s")
            .arg("--max-time")
            .arg(timeout.to_string())
            .arg("-X")
            .arg("POST")
            .arg("-H")
            .arg("Content-Type: application/json")
            .arg("-d")
            .arg(json_data)
            .arg(url);

        for header in headers {
            cmd.arg("-H").arg(header);
        }

        let output = cmd.output()?;
        let success = output.status.success();
        let response_text = String::from_utf8_lossy(&output.stdout).to_string();
        Ok((success, response_text))
    }

    fn curl_get(&self, url: &str, headers: &[&str], timeout: u64) -> Result<(bool, String)> {
        let mut cmd = Command::new("curl");
        cmd.arg("-s")
            .arg("--max-time")
            .arg(timeout.to_string())
            .arg(url);

        for header in headers {
            cmd.arg("-H").arg(header);
        }

        let output = cmd.output()?;
        let success = output.status.success();
        let response_text = String::from_utf8_lossy(&output.stdout).to_string();
        Ok((success, response_text))
    }

    fn curl_post_form(
        &self,
        url: &str,
        form_data: &str,
        headers: &[&str],
        timeout: u64,
    ) -> Result<(bool, String)> {
        let mut cmd = Command::new("curl");
        cmd.arg("-s")
            .arg("--max-time")
            .arg(timeout.to_string())
            .arg("-X")
            .arg("POST")
            .arg("-d")
            .arg(form_data)
            .arg(url);

        for header in headers {
            cmd.arg("-H").arg(header);
        }

        let output = cmd.output()?;
        let success = output.status.success();
        let response_text = String::from_utf8_lossy(&output.stdout).to_string();
        Ok((success, response_text))
    }

    fn curl_put_json(
        &self,
        url: &str,
        json_data: &str,
        headers: &[&str],
        timeout: u64,
    ) -> Result<(bool, String)> {
        let mut cmd = Command::new("curl");
        cmd.arg("-s")
            .arg("--max-time")
            .arg(timeout.to_string())
            .arg("-X")
            .arg("PUT")
            .arg("-H")
            .arg("Content-Type: application/json")
            .arg("-d")
            .arg(json_data)
            .arg(url);

        for header in headers {
            cmd.arg("-H").arg(header);
        }

        let output = cmd.output()?;
        let success = output.status.success();
        let response_text = String::from_utf8_lossy(&output.stdout).to_string();
        Ok((success, response_text))
    }

    fn push_telegram(&self, message: &str) -> Result<()> {
        if let Some(push_configs) = &self.config.push {
            for config in push_configs {
                if config.push_name == "Telegram" {
                    if let (Some(token), Some(user_id)) =
                        (&config.telegram_bot_token, &config.telegram_user_id)
                    {
                        let url = format!("https://api.telegram.org/bot{}/sendMessage", token);

                        let json_data = serde_json::json!({
                            "chat_id": user_id,
                            "parse_mode": "HTML",
                            "text": message
                        })
                        .to_string();

                        let (success, response_text) =
                            self.curl_post_json(&url, &json_data, &[], 20)?;

                        if success {
                            if let Ok(json) = serde_json::from_str::<Value>(&response_text) {
                                if json["ok"].as_bool().unwrap_or(false) {
                                    println!("Telegram 推送成功");
                                } else {
                                    println!("Telegram 推送失败");
                                }
                            }
                        } else {
                            println!("Telegram 推送失败");
                        }
                    }
                }
            }
        }
        Ok(())
    }

    fn push_pushplus(&self, message: &str) -> Result<()> {
        if let Some(push_configs) = &self.config.push {
            for config in push_configs {
                if config.push_name == "PushPlus" {
                    if let Some(token) = &config.pushplus_token {
                        let json_data = serde_json::json!({
                            "token": token,
                            "title": "Cloudflare优选IP",
                            "content": message,
                            "template": "html"
                        })
                        .to_string();

                        let (success, response_text) = self.curl_post_json(
                            "http://www.pushplus.plus/send",
                            &json_data,
                            &[],
                            20,
                        )?;

                        if success {
                            if let Ok(json) = serde_json::from_str::<Value>(&response_text) {
                                if json["code"].as_i64().unwrap_or(-1) == 200 {
                                    println!("PushPlus 推送成功");
                                } else {
                                    let msg = json["msg"].as_str().unwrap_or("未知错误");
                                    println!("PushPlus 推送失败：{}", msg);
                                }
                            }
                        } else {
                            println!("PushPlus 推送失败");
                        }
                    }
                }
            }
        }
        Ok(())
    }

    fn push_server_chan(&self, message: &str) -> Result<()> {
        if let Some(push_configs) = &self.config.push {
            for config in push_configs {
                if config.push_name == "Server酱" {
                    if let Some(sendkey) = &config.server_sendkey {
                        let form_data = format!(
                            "title=Cloudflare优选IP&desp={}",
                            urlencoding::encode(message)
                        );

                        let (success, response_text) = self.curl_post_form(
                            &format!("https://sctapi.ftqq.com/{}.send", sendkey),
                            &form_data,
                            &[],
                            20,
                        )?;

                        if success {
                            if let Ok(json) = serde_json::from_str::<Value>(&response_text) {
                                if json["code"].as_i64().unwrap_or(-1) == 0 {
                                    println!("Server酱 推送成功");
                                } else {
                                    let msg = json["message"].as_str().unwrap_or("未知错误");
                                    println!("Server酱 推送失败：{}", msg);
                                }
                            }
                        } else {
                            println!("Server酱 推送失败");
                        }
                    }
                }
            }
        }
        Ok(())
    }

    fn push_pushdeer(&self, message: &str) -> Result<()> {
        if let Some(push_configs) = &self.config.push {
            for config in push_configs {
                if config.push_name == "PushDeer" {
                    if let Some(pushkey) = &config.pushdeer_pushkey {
                        let url =
                            format!("https://api2.pushdeer.com/message/push?pushkey={}", pushkey);

                        let form_data = format!(
                            "text=Cloudflare优选IP&desp={}",
                            urlencoding::encode(message)
                        );

                        let (success, response_text) =
                            self.curl_post_form(&url, &form_data, &[], 20)?;

                        if success {
                            if let Ok(json) = serde_json::from_str::<Value>(&response_text) {
                                if json["code"].as_i64().unwrap_or(-1) == 0 {
                                    println!("PushDeer 推送成功");
                                } else {
                                    let error = json["error"].as_str().unwrap_or("未知错误");
                                    println!("PushDeer 推送失败：{}", error);
                                }
                            }
                        } else {
                            println!("PushDeer 推送失败");
                        }
                    }
                }
            }
        }
        Ok(())
    }

    fn push_wechat_work(&self, message: &str) -> Result<()> {
        if let Some(push_configs) = &self.config.push {
            for config in push_configs {
                if config.push_name == "企业微信" {
                    let corpid = config.wechat_corpid.as_ref();
                    let secret = config.wechat_secret.as_ref();
                    let agentid = config.wechat_agentid.as_ref();
                    let userid = config.wechat_userid.as_ref();

                    if let (Some(corpid), Some(secret), Some(agentid), Some(userid)) =
                        (corpid, secret, agentid, userid)
                    {
                        // 获取access_token
                        let token_url = format!(
                            "https://qyapi.weixin.qq.com/cgi-bin/gettoken?corpid={}&corpsecret={}",
                            corpid, secret
                        );

                        let (success, response_text) = self.curl_get(&token_url, &[], 20)?;

                        if success {
                            if let Ok(json) = serde_json::from_str::<Value>(&response_text) {
                                if json["errcode"].as_i64().unwrap_or(-1) == 0 {
                                    let access_token = json["access_token"].as_str().unwrap_or("");
                                    let send_url = format!(
                                        "https://qyapi.weixin.qq.com/cgi-bin/message/send?access_token={}",
                                        access_token
                                    );

                                    let json_data = serde_json::json!({
                                        "touser": userid,
                                        "msgtype": "text",
                                        "agentid": agentid,
                                        "text": {
                                            "content": message
                                        }
                                    })
                                    .to_string();

                                    let (send_success, send_response_text) =
                                        self.curl_post_json(&send_url, &json_data, &[], 20)?;

                                    if send_success {
                                        if let Ok(send_json) =
                                            serde_json::from_str::<Value>(&send_response_text)
                                        {
                                            match send_json["errcode"].as_i64().unwrap_or(-1) {
                                                0 => println!("企业微信推送成功"),
                                                81013 => println!(
                                                    "企业微信 USERID 填写错误，请检查后重试"
                                                ),
                                                60020 => println!(
                                                    "企业微信应用未配置本机IP地址，请在企业微信后台添加IP白名单"
                                                ),
                                                _ => {
                                                    let errmsg = send_json["errmsg"]
                                                        .as_str()
                                                        .unwrap_or("未知错误");
                                                    println!("企业微信推送失败：{}", errmsg);
                                                }
                                            }
                                        }
                                    } else {
                                        println!("企业微信发送消息失败");
                                    }
                                } else {
                                    let errmsg = json["errmsg"].as_str().unwrap_or("未知错误");
                                    println!(
                                        "access_token 获取失败，请检查 CORPID 和 SECRET: {}",
                                        errmsg
                                    );
                                }
                            }
                        } else {
                            println!("企业微信获取Token失败");
                        }
                    }
                }
            }
        }
        Ok(())
    }

    fn push_synology_chat(&self, message: &str) -> Result<()> {
        if let Some(push_configs) = &self.config.push {
            for config in push_configs {
                if config.push_name == "Synology-Chat" {
                    if let Some(url) = &config.synology_chat_url {
                        let json_data = serde_json::json!({
                            "text": message
                        })
                        .to_string();

                        let (success, response_text) =
                            self.curl_post_json(url, &json_data, &[], 20)?;

                        if success {
                            if let Ok(json) = serde_json::from_str::<Value>(&response_text) {
                                if json["success"].as_bool().unwrap_or(false) {
                                    println!("Synology-Chat 推送成功");
                                } else {
                                    let error = json["error"].as_str().unwrap_or("未知错误");
                                    println!("Synology-Chat 推送失败：{}", error);
                                }
                            }
                        } else {
                            println!("Synology-Chat 推送失败");
                        }
                    }
                }
            }
        }
        Ok(())
    }

    fn push_github(&self, ddns_name: &str, domain_ip_mapping: &[(String, String)]) -> Result<()> {
        if let Some(github_push_configs) = &self.config.github_push {
            for config in github_push_configs {
                if config.ddns_push == ddns_name {
                    // 解析文件URL获取参数
                    let re = regex::Regex::new(
                        r"^https://raw\.githubusercontent\.com/([^/]+)/([^/]+)/refs/heads/([^/]+)/(.+)\?token=(.+)$",
                    )?;
                    if let Some(captures) = re.captures(&config.file_url) {
                        let token = &captures[5];
                        let repo = format!("{}/{}", &captures[1], &captures[2]);
                        let branch = &captures[3];
                        let remote_path = &captures[4];

                        // 处理当前的IP地址
                        let mut processed_ips = String::new();
                        for (_domain, ip_str) in domain_ip_mapping.iter() {
                            let processed_ip = if ip_str.contains('.') {
                                // IPv4地址
                                if !config.remark.is_empty() {
                                    format!("{}:{}#{}", ip_str, config.port, config.remark)
                                } else {
                                    ip_str.to_string()
                                }
                            } else {
                                // IPv6地址
                                if !config.remark6.is_empty() {
                                    format!("[{}]:{}#{}", ip_str, config.port, config.remark6)
                                } else {
                                    format!("[{}]", ip_str)
                                }
                            };
                            processed_ips.push_str(&format!("{}\n", processed_ip));
                        }

                        // 去除空行和重复行
                        let lines: Vec<&str> = processed_ips
                            .lines()
                            .filter(|line| !line.is_empty())
                            .collect();
                        let unique_lines: Vec<&str> = lines
                            .iter()
                            .cloned()
                            .collect::<std::collections::HashSet<_>>()
                            .into_iter()
                            .collect();
                        let new_content = unique_lines.join("\n");

                        // 检查文件是否存在
                        let check_url = format!(
                            "https://api.github.com/repos/{}/contents/{}",
                            repo, remote_path
                        );
                        let auth_header = format!("Authorization: token {}", token);

                        let (check_success, check_response_text) =
                            self.curl_get(&check_url, &[&auth_header], 20)?;

                        if !check_success
                            || check_response_text.contains("\"message\":\"Not Found\"")
                            || check_response_text.contains("\"message\": \"Not Found\"")
                        {
                            // 文件不存在，创建新文件
                            let create_url = format!(
                                "https://api.github.com/repos/{}/contents/{}",
                                repo, remote_path
                            );

                            let json_data = serde_json::json!({
                                "message": "创建 Cloudflare 优选 IP 文件",
                                "content": general_purpose::STANDARD.encode(&new_content),
                                "branch": branch
                            })
                            .to_string();

                            let (create_success, create_response_text) = self.curl_put_json(
                                &create_url,
                                &json_data,
                                &[&auth_header, "Accept: application/vnd.github.v3+json"],
                                20,
                            )?;

                            if create_success && create_response_text.contains("\"commit\"") {
                                println!("Github 推送成功");
                            } else {
                                println!("Github 创建文件失败，返回内容：{}", create_response_text);
                            }
                        } else if check_success {
                            // 文件存在，更新文件
                            if let Ok(check_json) =
                                serde_json::from_str::<Value>(&check_response_text)
                            {
                                let sha = check_json["sha"].as_str().unwrap_or("");

                                // 获取现有内容并解码
                                let existing_content_encoded =
                                    check_json["content"].as_str().unwrap_or("");
                                // 移除base64字符串中的换行符
                                let clean_base64 = existing_content_encoded
                                    .replace(|c| c == '\n' || c == '\r', "");
                                let existing_content_decoded =
                                    general_purpose::STANDARD.decode(clean_base64)?;
                                let existing_content = String::from_utf8(existing_content_decoded)?;

                                // 从现有内容中过滤掉当前记录
                                let filtered_content =
                                    self.filter_github_content(&existing_content, &config)?;

                                // 合并新内容和过滤后的内容
                                let mut final_content = filtered_content;
                                if !final_content.is_empty() && !new_content.is_empty() {
                                    final_content.push('\n');
                                }
                                final_content.push_str(&new_content);

                                // 确保末尾有换行符
                                if !final_content.is_empty() && !final_content.ends_with('\n') {
                                    final_content.push('\n');
                                }

                                let update_url = format!(
                                    "https://api.github.com/repos/{}/contents/{}",
                                    repo, remote_path
                                );

                                let json_data = serde_json::json!({
                                    "message": "更新 Cloudflare 优选 IP",
                                    "content": general_purpose::STANDARD.encode(&final_content),
                                    "sha": sha,
                                    "branch": branch
                                })
                                .to_string();

                                let (update_success, update_response_text) = self.curl_put_json(
                                    &update_url,
                                    &json_data,
                                    &[&auth_header, "Accept: application/vnd.github.v3+json"],
                                    20,
                                )?;

                                if update_success && update_response_text.contains("\"commit\"") {
                                    println!("Github 推送成功");
                                } else {
                                    println!("Github 更新文件失败");
                                }
                            }
                        } else {
                            println!("Github 检查文件失败");
                        }
                    } else {
                        println!("参数错误");
                    }
                }
            }
        }
        Ok(())
    }

    // 过滤 GitHub 内容，移除特定记录
    fn filter_github_content(&self, content: &str, config: &GithubPushConfig) -> Result<String> {
        let lines: Vec<&str> = content.lines().collect();
        let mut filtered_lines = Vec::new();

        for line in lines {
            let line = line.trim();
            if line.is_empty() {
                continue;
            }

            // 检查是否是当前配置的记录
            let is_current_config_record = if line.contains('.') {
                // IPv4 记录
                !config.remark.is_empty()
                    && line.ends_with(&format!(":{}#{}", config.port, config.remark))
            } else {
                // IPv6 记录（以 [ 开头）
                line.starts_with('[')
                    && !config.remark6.is_empty()
                    && line.contains(&format!("]:{}#{}", config.port, config.remark6))
            };

            // 如果不是当前配置的记录，则保留
            if !is_current_config_record {
                filtered_lines.push(line);
            }
        }

        Ok(filtered_lines.join("\n"))
    }
}

impl_settings!(PushService);