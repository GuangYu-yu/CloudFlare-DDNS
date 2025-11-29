use anyhow::Result;
use serde::Deserialize;
use serde_json::Value;
use std::fmt::Arguments;
use std::process::Command;

#[derive(Debug, Deserialize)]
pub struct DnsRecord {
    pub id: String,
    pub content: String,
}

// 带缩进的错误打印函数，用于统一处理缩进和错误消息
fn indented_error_println(args: Arguments) {
    print!("  ");
    crate::error_println(args);
}

pub trait DnsOperations {
    /// 获取DNS记录
    fn get_dns_records(
        &self,
        x_email: &str,
        api_key: &str,
        zone_id: &str,
        domain: &str,
        record_type: Option<&str>,
    ) -> Result<Vec<DnsRecord>>;

    /// 删除DNS记录
    fn delete_dns_record(
        &self,
        x_email: &str,
        api_key: &str,
        zone_id: &str,
        record_id: &str,
    ) -> Result<bool>;

    /// 创建DNS记录
    fn create_dns_record(
        &self,
        x_email: &str,
        api_key: &str,
        zone_id: &str,
        domain: &str,
        record_type: &str,
        ip: &str,
    ) -> Result<bool>;
}

impl DnsOperations for super::start_struct::Start {
    fn get_dns_records(
        &self,
        x_email: &str,
        api_key: &str,
        zone_id: &str,
        domain: &str,
        record_type: Option<&str>,
    ) -> Result<Vec<DnsRecord>> {
        let url = if let Some(rt) = record_type {
            format!(
                "https://api.cloudflare.com/client/v4/zones/{}/dns_records?type={}&name={}",
                zone_id, rt, domain
            )
        } else {
            format!(
                "https://api.cloudflare.com/client/v4/zones/{}/dns_records?name={}",
                zone_id, domain
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

        if !json["success"].as_bool().unwrap_or(false) {
            let error_message = json["errors"][0]["message"].as_str().unwrap_or("未知错误");
            return Err(anyhow::anyhow!("获取DNS记录失败: {}", error_message));
        }

        let records: Vec<DnsRecord> = json["result"]
            .as_array()
            .unwrap_or(&Vec::new())
            .iter()
            .filter_map(|item| {
                let id = item["id"].as_str()?.to_string();
                let content = item["content"].as_str()?.to_string();
                Some(DnsRecord { id, content })
            })
            .collect();

        Ok(records)
    }

    fn delete_dns_record(
        &self,
        x_email: &str,
        api_key: &str,
        zone_id: &str,
        record_id: &str,
    ) -> Result<bool> {
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
                indented_error_println(format_args!("删除DNS记录失败: {}", e));
                return Ok(false);
            }
        };

        if !output.status.success() {
            let stderr = String::from_utf8_lossy(&output.stderr);
            indented_error_println(format_args!("删除DNS记录失败: {}", stderr));
            Ok(false)
        } else {
            let response_text = String::from_utf8_lossy(&output.stdout);
            let json: Value = match serde_json::from_str(&response_text) {
                Ok(j) => j,
                Err(e) => {
                    indented_error_println(format_args!("解析响应JSON失败: {}", e));
                    return Ok(false);
                }
            };

            if json["success"].as_bool().unwrap_or(false) {
                Ok(true)
            } else {
                let error_message = json["errors"][0]["message"].as_str().unwrap_or("未知错误");
                indented_error_println(format_args!("删除DNS记录失败: {}", error_message));
                Ok(false)
            }
        }
    }

    fn create_dns_record(
        &self,
        x_email: &str,
        api_key: &str,
        zone_id: &str,
        domain: &str,
        record_type: &str,
        ip: &str,
    ) -> Result<bool> {
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
                indented_error_println(format_args!("创建DNS记录失败: {}", e));
                return Ok(false);
            }
        };

        if !output.status.success() {
            let stderr = String::from_utf8_lossy(&output.stderr);
            indented_error_println(format_args!("创建DNS记录失败: {}", stderr));
            return Ok(false);
        }

        let response_text = String::from_utf8_lossy(&output.stdout);
        let json: Value = match serde_json::from_str(&response_text) {
            Ok(j) => j,
            Err(e) => {
                indented_error_println(format_args!("解析响应JSON失败: {}", e));
                return Ok(false);
            }
        };

        let success = json["success"].as_bool().unwrap_or(false);

        if success {
            Ok(true)
        } else {
            let code = json["errors"][0]["code"].as_i64().unwrap_or(0);
            let error_message = json["errors"][0]["message"].as_str().unwrap_or("未知错误");

            // 如果出现错误代码 81057，表示已有相同记录，不需要更新
            if code == 81057 {
                print!("  ");
                crate::warning_println(format_args!("已有 {} 的记录，不做更新", ip));
                Ok(false)
            } else {
                indented_error_println(format_args!("添加DNS记录失败: {}", error_message));
                Ok(false)
            }
        }
    }
}