use crate::{
    Config, GithubPushConfig, Settings, error_println, impl_settings, info_println,
    print_section_header, success_println, warning_println,
};
use anyhow::Result;
use base64::{Engine as _, engine::general_purpose};
use regex::Regex;
use serde_json::Value;
use std::collections::HashSet;
use std::fs;
use std::path::{Path, PathBuf};
use std::process::Command;

pub struct PushService {
    config_path: PathBuf,
    config: Config,
}

impl PushService {
    pub fn new(config_path: &Path) -> Result<Self> {
        let mut service = Self {
            config_path: config_path.to_path_buf(),
            config: Config::default(),
        };
        service.load_config()?;
        Ok(service)
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
        let push_modes: Vec<&str> = push_mod.split_whitespace().collect();
        if !push_modes.iter().any(|&mode| mode != "不设置") {
            info_println(format_args!("根据配置跳过推送"));
            return Ok(());
        }

        if domain_ip_mapping.is_empty() {
            info_println(format_args!("没有更新信息，跳过推送"));
            return Ok(());
        }

        print_section_header("推送任务");

        let ip_info = self.process_csv_file(csvfile, hostnames, v4_num, v6_num, ip_type)?;

        for mode in push_modes {
            let res = match mode {
                "Telegram" | "PushPlus" | "Server酱" | "PushDeer" | "企业微信"
                | "Synology-Chat" => self.push_with_config(mode, &ip_info),
                "Github" => self.push_github(ddns_name, domain_ip_mapping),
                _ => {
                    warning_println(format_args!("未知的推送模式: {}", mode));
                    continue;
                }
            };
            self.push_result(mode, res);
        }

        info_println(format_args!("推送任务完成"));
        Ok(())
    }

    fn push_result(&self, name: &str, res: Result<()>) {
        match res {
            Ok(_) => success_println(format_args!("{}", name)),
            Err(e) => error_println(format_args!("{} 推送失败: {:?}", name, e)),
        }
    }

    fn push_with_config(&self, push_name: &str, message: &str) -> Result<()> {
        if let Some(configs) = &self.config.push {
            for config in configs.iter().filter(|c| c.push_name == push_name) {
                match push_name {
                    "Telegram" => self.telegram_send(config, message)?,
                    "PushPlus" => self.pushplus_send(config, message)?,
                    "Server酱" => self.server_chan_send(config, message)?,
                    "PushDeer" => self.pushdeer_send(config, message)?,
                    "企业微信" => self.wechat_work_send(config, message)?,
                    "Synology-Chat" => self.synology_chat_send(config, message)?,
                    _ => {}
                }
            }
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
        let domain_arr: Vec<&str> = hostnames.split_whitespace().collect();

        let csv_data: Vec<Vec<String>> = lines
            .iter()
            .skip(1)
            .take(ip_count as usize)
            .map(|line| line.split(',').map(|s| s.to_string()).collect::<Vec<_>>())
            .filter(|fields| fields.len() >= 7)
            .collect();

        let ips: Vec<&String> = csv_data.iter().map(|f| &f[0]).collect();
        let latency: Vec<String> = csv_data.iter().map(|f| format!("{} ms", f[4])).collect();
        let speed: Vec<String> = csv_data
            .iter()
            .filter_map(|f| {
                let val = f[5].trim();
                if !val.is_empty() {
                    Some(format!("{} MB/s", val))
                } else {
                    None
                }
            })
            .collect();
        let datacenter: Vec<&String> = csv_data.iter().map(|f| &f[6]).collect();

        let mut result = String::new();
        result.push_str(&format!("{} 地址：\n", ip_type));
        for ip in &ips {
            result.push_str(&format!("{}\n", ip));
        }

        result.push_str("━━━━━━━━━━━━━━━━━━━\n域名：\n");
        for (i, domain) in domain_arr.iter().enumerate() {
            if i < ips.len() {
                result.push_str(&format!("{}\n", domain));
            }
        }

        result.push_str("━━━━━━━━━━━━━━━━━━━\n平均延迟：\n");
        for l in &latency {
            result.push_str(&format!("{}\n", l));
        }

        result.push_str("━━━━━━━━━━━━━━━━━━━\n下载速度：\n");
        for s in &speed {
            result.push_str(&format!("{}\n", s));
        }

        result.push_str("━━━━━━━━━━━━━━━━━━━\n数据中心：\n");
        for d in &datacenter {
            result.push_str(&format!("{}\n", d));
        }

        Ok(result)
    }

    fn curl_request(
        &self,
        method: &str,
        url: &str,
        data: Option<&str>,
        headers: &[&str],
        timeout: u64,
    ) -> Result<(bool, String)> {
        let mut cmd = Command::new("curl");
        cmd.arg("-s").arg("--max-time").arg(timeout.to_string());
        match method {
            "POST" | "PUT" => {
                cmd.arg("-X").arg(method);
                if let Some(d) = data {
                    cmd.arg("-d").arg(d);
                }
                cmd.arg("-H").arg("Content-Type: application/json");
            }
            _ => {}
        }
        cmd.arg(url);
        for h in headers {
            cmd.arg("-H").arg(h);
        }
        let output = cmd.output()?;
        Ok((
            output.status.success(),
            String::from_utf8_lossy(&output.stdout).to_string(),
        ))
    }

    fn telegram_send(&self, config: &crate::PushConfig, message: &str) -> Result<()> {
        if let (Some(token), Some(user_id)) = (&config.telegram_bot_token, &config.telegram_user_id)
        {
            let url = format!("https://api.telegram.org/bot{}/sendMessage", token);
            let json_data =
                serde_json::json!({ "chat_id": user_id, "parse_mode": "HTML", "text": message })
                    .to_string();
            let (success, resp) = self.curl_request("POST", &url, Some(&json_data), &[], 20)?;
            if !success
                || !serde_json::from_str::<Value>(&resp)
                    .map(|v| v["ok"].as_bool().unwrap_or(false))
                    .unwrap_or(false)
            {
                error_println(format_args!("Telegram 推送失败"));
            }
        }
        Ok(())
    }

    fn pushplus_send(&self, config: &crate::PushConfig, message: &str) -> Result<()> {
        if let Some(token) = &config.pushplus_token {
            let json_data = serde_json::json!({
                "token": token, "title": "Cloudflare优选IP", "content": message, "template": "html"
            })
            .to_string();
            let (success, resp) = self.curl_request(
                "POST",
                "http://www.pushplus.plus/send",
                Some(&json_data),
                &[],
                20,
            )?;
            if !success
                || !serde_json::from_str::<Value>(&resp)
                    .map(|v| v["code"].as_i64().unwrap_or(-1) == 200)
                    .unwrap_or(false)
            {
                error_println(format_args!("PushPlus 推送失败"));
            }
        }
        Ok(())
    }

    fn server_chan_send(&self, config: &crate::PushConfig, message: &str) -> Result<()> {
        if let Some(sendkey) = &config.server_sendkey {
            let form_data = format!(
                "title=Cloudflare优选IP&desp={}",
                urlencoding::encode(message)
            );
            let (success, resp) = self.curl_request(
                "POST",
                &format!("https://sctapi.ftqq.com/{}.send", sendkey),
                Some(&form_data),
                &[],
                20,
            )?;
            if !success
                || !serde_json::from_str::<Value>(&resp)
                    .map(|v| v["code"].as_i64().unwrap_or(-1) == 0)
                    .unwrap_or(false)
            {
                error_println(format_args!("Server酱 推送失败"));
            }
        }
        Ok(())
    }

    fn pushdeer_send(&self, config: &crate::PushConfig, message: &str) -> Result<()> {
        if let Some(pushkey) = &config.pushdeer_pushkey {
            let url = format!("https://api2.pushdeer.com/message/push?pushkey={}", pushkey);
            let form_data = format!(
                "text=Cloudflare优选IP&desp={}",
                urlencoding::encode(message)
            );
            let (success, resp) = self.curl_request("POST", &url, Some(&form_data), &[], 20)?;
            if !success
                || !serde_json::from_str::<Value>(&resp)
                    .map(|v| v["code"].as_i64().unwrap_or(-1) == 0)
                    .unwrap_or(false)
            {
                error_println(format_args!("PushDeer 推送失败"));
            }
        }
        Ok(())
    }

    fn wechat_work_send(&self, config: &crate::PushConfig, message: &str) -> Result<()> {
        if let (Some(corpid), Some(secret), Some(agentid), Some(userid)) = (
            &config.wechat_corpid,
            &config.wechat_secret,
            &config.wechat_agentid,
            &config.wechat_userid,
        ) {
            let token_url = format!(
                "https://qyapi.weixin.qq.com/cgi-bin/gettoken?corpid={}&corpsecret={}",
                corpid, secret
            );
            let (success, resp) = self.curl_request("GET", &token_url, None, &[], 20)?;
            if success {
                if let Ok(json) = serde_json::from_str::<Value>(&resp) {
                    if json["errcode"].as_i64().unwrap_or(-1) == 0 {
                        let access_token = json["access_token"].as_str().unwrap_or("");
                        let send_url = format!(
                            "https://qyapi.weixin.qq.com/cgi-bin/message/send?access_token={}",
                            access_token
                        );
                        let json_data = serde_json::json!({
                            "touser": userid, "msgtype": "text", "agentid": agentid, "text": { "content": message }
                        }).to_string();
                        let (send_success, _) =
                            self.curl_request("POST", &send_url, Some(&json_data), &[], 20)?;
                        if !send_success {
                            error_println(format_args!("企业微信发送消息失败"));
                        }
                    } else {
                        error_println(format_args!("企业微信获取Token失败"));
                    }
                }
            } else {
                error_println(format_args!("企业微信获取Token失败"));
            }
        }
        Ok(())
    }

    fn synology_chat_send(&self, config: &crate::PushConfig, message: &str) -> Result<()> {
        if let Some(url) = &config.synology_chat_url {
            let json_data = serde_json::json!({ "text": message }).to_string();
            let (success, resp) = self.curl_request("POST", url, Some(&json_data), &[], 20)?;
            if !success
                || !serde_json::from_str::<Value>(&resp)
                    .map(|v| v["success"].as_bool().unwrap_or(false))
                    .unwrap_or(false)
            {
                error_println(format_args!("Synology-Chat 推送失败"));
            }
        }
        Ok(())
    }

    fn push_github(&self, ddns_name: &str, domain_ip_mapping: &[(String, String)]) -> Result<()> {
        // 将正则表达式移到循环外
        let re = Regex::new(
            r"^https://raw\.githubusercontent\.com/([^/]+)/([^/]+)/refs/heads/([^/]+)/(.+)\?token=(.+)$",
        )?;

        if let Some(github_push_configs) = &self.config.github_push {
            for config in github_push_configs
                .iter()
                .filter(|c| c.ddns_push == ddns_name)
            {
                if let Some(caps) = re.captures(&config.file_url) {
                    let token = &caps[5];
                    let repo = format!("{}/{}", &caps[1], &caps[2]);
                    let branch = &caps[3];
                    let remote_path = &caps[4];

                    let mut new_content = domain_ip_mapping
                        .iter()
                        .map(|(_d, ip)| {
                            if ip.contains('.') {
                                if !config.remark.is_empty() {
                                    format!("{}:{}#{}", ip, config.port, config.remark)
                                } else {
                                    ip.clone()
                                }
                            } else if !config.remark6.is_empty() {
                                format!("[{}]:{}#{}", ip, config.port, config.remark6)
                            } else {
                                format!("[{}]", ip)
                            }
                        })
                        .collect::<Vec<String>>()
                        .join("\n");

                    // 去重
                    let set: HashSet<_> = new_content.lines().filter(|l| !l.is_empty()).collect();
                    new_content = set
                        .into_iter()
                        .map(|s| s.to_string())
                        .collect::<Vec<_>>()
                        .join("\n");

                    let check_url = format!(
                        "https://api.github.com/repos/{}/contents/{}",
                        repo, remote_path
                    );
                    let auth_header = format!("Authorization: token {}", token);
                    let (check_success, check_resp) =
                        self.curl_request("GET", &check_url, None, &[&auth_header], 20)?;

                    if check_success {
                        if let Ok(check_json) = serde_json::from_str::<Value>(&check_resp) {
                            let sha = check_json["sha"].as_str().unwrap_or("");
                            let existing_content_encoded = check_json["content"]
                                .as_str()
                                .unwrap_or("")
                                .replace(['\n', '\r'], "");
                            let existing_content = String::from_utf8(
                                general_purpose::STANDARD.decode(existing_content_encoded)?,
                            )?;
                            let mut final_content =
                                self.filter_github_content(&existing_content, config)?;
                            if !final_content.is_empty() && !new_content.is_empty() {
                                final_content.push('\n');
                            }
                            final_content.push_str(&new_content);
                            if !final_content.ends_with('\n') {
                                final_content.push('\n');
                            }
                            let json_data = serde_json::json!({
                                "message": "更新 Cloudflare 优选 IP",
                                "content": general_purpose::STANDARD.encode(&final_content),
                                "sha": sha,
                                "branch": branch
                            })
                            .to_string();
                            let _ = self.curl_request(
                                "PUT",
                                &check_url,
                                Some(&json_data),
                                &[&auth_header, "Accept: application/vnd.github.v3+json"],
                                20,
                            )?;
                        }
                    } else {
                        // 创建文件
                        let json_data = serde_json::json!({
                            "message": "创建 Cloudflare 优选 IP 文件",
                            "content": general_purpose::STANDARD.encode(&new_content),
                            "branch": branch
                        })
                        .to_string();
                        let _ = self.curl_request(
                            "PUT",
                            &check_url,
                            Some(&json_data),
                            &[&auth_header, "Accept: application/vnd.github.v3+json"],
                            20,
                        )?;
                    }
                }
            }
        }
        Ok(())
    }

    fn filter_github_content(&self, content: &str, config: &GithubPushConfig) -> Result<String> {
        let lines: Vec<&str> = content.lines().collect();
        let mut filtered_lines = Vec::new();
        for line in lines {
            let line = line.trim();
            if line.is_empty() {
                continue;
            }
            let is_current = if line.contains('.') {
                !config.remark.is_empty()
                    && line.ends_with(&format!(":{}#{}", config.port, config.remark))
            } else {
                line.starts_with('[')
                    && !config.remark6.is_empty()
                    && line.contains(&format!("]:{}#{}", config.port, config.remark6))
            };
            if !is_current {
                filtered_lines.push(line);
            }
        }
        Ok(filtered_lines.join("\n"))
    }
}

impl_settings!(PushService);