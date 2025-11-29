use anyhow::Result;
use std::process::Command;

pub trait CloudflareApi {
    /// 验证Cloudflare账户
    fn validate_cloudflare_account(
        &self,
        x_email: &str,
        api_key: &str,
        zone_id: &str,
    ) -> Result<()>;
}

impl CloudflareApi for super::start_struct::Start {
    fn validate_cloudflare_account(
        &self,
        x_email: &str,
        api_key: &str,
        zone_id: &str,
    ) -> Result<()> {
        crate::print_section_header("Cloudflare 账号验证");

        let max_retries = 10;
        let retry_delay = std::time::Duration::from_secs(2);
        let timeout = std::time::Duration::from_secs(5);

        let url = format!("https://api.cloudflare.com/client/v4/zones/{}", zone_id);

        for attempt in 1..=max_retries {
            crate::info_println(format_args!("第 {} 次登录尝试 ", attempt));

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
                    crate::info_println(format_args!("收到 Cloudflare 响应"));

                    if output.status.success() {
                        let response_text = String::from_utf8_lossy(&output.stdout);
                        let json: serde_json::Value = serde_json::from_str(&response_text)?;

                        if json["success"].as_bool().unwrap_or(false) {
                            crate::success_println(format_args!("Cloudflare 账号验证成功"));
                            return Ok(());
                        } else {
                            let error_message =
                                json["errors"][0]["message"].as_str().unwrap_or("未知错误");
                            crate::error_println(format_args!(
                                "第 {} / {} 次登录失败",
                                attempt, max_retries
                            ));
                            crate::error_println(format_args!("错误信息: {}", error_message));
                        }
                    } else {
                        let stderr = String::from_utf8_lossy(&output.stderr);
                        crate::error_println(format_args!("登录尝试失败，错误: {}", stderr));
                    }
                }

                Err(e) => {
                    crate::error_println(format_args!("登录尝试失败，错误: {}", e));
                }
            }

            if attempt < max_retries {
                crate::warning_println(format_args!("等待 {} 秒后重试...", retry_delay.as_secs()));
                std::thread::sleep(retry_delay);
            }
        }

        Err(anyhow::anyhow!(
            "登录失败，已达到最大重试次数 {}",
            max_retries
        ))
    }
}