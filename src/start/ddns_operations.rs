use anyhow::Result;
use super::ip_operations::IpOperations;
#[cfg(target_os = "linux")]
use std::process::Command;

pub trait DdnsOperations {
    /// 运行DDNS更新流程
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

        #[cfg(target_os = "linux")]
        clien: &str,

    ) -> Result<()>;
}

impl DdnsOperations for super::start_struct::Start {
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

        #[cfg(target_os = "linux")]
        clien: &str,

    ) -> Result<()> {
        // ========== 构造域名 ==========
        let domains: Vec<String> = if add_ddns != "未指定" {
            hostname2
                .split_whitespace()
                .map(|sub| format!("{}.{}", sub, hostname1))
                .collect()
        } else {
            Vec::new()
        };

        let hostnames = domains.join(" ");

        crate::print_section_header("插件暂停");

        // ========== 插件控制：停止 ==========
        #[cfg(target_os = "linux")]
        let plugin_status = if clien != "未指定" && !clien.is_empty() {
            crate::info_println(format_args!("正在停止插件 {}", clien));
            let status = Command::new(format!("/etc/init.d/{}", clien))
                .arg("stop")
                .status()?;
            if status.success() {
                crate::info_println(format_args!("已停止插件 {}", clien));
                Some("stopped")
            } else {
                crate::error_println(format_args!("停止插件 {} 失败", clien));
                None
            }
        } else {
            crate::info_println(format_args!("按配置不停止插件"));
            None
        };

        #[cfg(not(target_os = "linux"))]
        {
            crate::info_println(format_args!("当前系统不需要处理插件"));
        }

        // 解析 cf_command 获取 -f 参数指定的文件路径
        let output_file = super::utils::parse_cf_command_for_file(cf_command, "-f");

        let mut all_domain_ip_map = std::collections::HashMap::new();

        // 通用IP处理函数
        let process_ip =
            |ip_type: &str,
             url: &str,
             num: u32|
             -> Result<(Vec<String>, std::collections::HashMap<String, Vec<String>>)> {
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

                    #[cfg(target_os = "linux")]
                    plugin_status.as_deref(),

                    #[cfg(target_os = "linux")]
                    clien,

                )
            };

        // 通用消息推送函数
        let execute_push_for_ip = |ip_type: &str, ips: &[String]| -> Result<()> {
            if !ips.is_empty() {
                self.execute_push(
                    push_mod, &hostnames, v4_num, v6_num, ip_type, ddns_name, ips, &domains,
                    add_ddns, cf_command,
                )?;
            }
            Ok(())
        };

        // 处理IPv4和IPv6都为0的情况
        if v4_num == 0 && v6_num == 0 {
            crate::info_println(format_args!("IPv4和IPv6所需数量都设为0，跳过测速并直接推送消息"));

            // 读取所有IPv4地址
            let v4_ips = Self::read_ips_from_csv("IPv4", 0, cf_command)?;

            // 读取所有IPv6地址
            let v6_ips = Self::read_ips_from_csv("IPv6", 0, cf_command)?;

            // 推送结果
            execute_push_for_ip("IPv4", &v4_ips)?;
            execute_push_for_ip("IPv6", &v6_ips)?;
        } else {
            // 处理IPv4
            if v4_num > 0 {
                let (v4_ips, v4_domain_ip_map) = process_ip("IPv4", v4_url, v4_num)?;

                all_domain_ip_map.extend(v4_domain_ip_map);
                execute_push_for_ip("IPv4", &v4_ips)?;
            } else {
                crate::info_println(format_args!("根据设置，跳过 IPv4 测速"));
            }

            // 处理IPv6
            if v6_num > 0 {
                let (v6_ips, v6_domain_ip_map) = process_ip("IPv6", v6_url, v6_num)?;

                all_domain_ip_map.extend(v6_domain_ip_map);
                execute_push_for_ip("IPv6", &v6_ips)?;
            } else {
                crate::info_println(format_args!("根据设置，跳过 IPv6 测速"));
            }
        }

        // ========== 插件控制：恢复 ==========
        #[cfg(target_os = "linux")]
        if clien != "未指定" && !clien.is_empty() {
            if let Some("stopped") = plugin_status {
                crate::print_section_header("插件恢复");
                crate::info_println(format_args!("正在恢复插件 {}", clien));
                let status = Command::new(format!("/etc/init.d/{}", clien))
                    .arg("start")
                    .status();
                if status.is_ok() && status.unwrap().success() {
                    crate::info_println(format_args!("已恢复插件 {}", clien));
                } else {
                    crate::error_println(format_args!("恢复插件 {} 失败", clien));
                }
            }
        }

        // 退出程序
        std::process::exit(0);
    }
}