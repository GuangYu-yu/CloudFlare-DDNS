use super::ip_operations::IpOperations;
use anyhow::Result;
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

        #[cfg(target_os = "linux")] clien: &str,
    ) -> Result<()>;

    /// 控制插件的启动和停止
    #[cfg(target_os = "linux")]
    fn control_plugin(&self, clien: &str, action: &str) -> Result<Option<&'static str>>;

    /// 推送IP地址的辅助函数
    fn push_ips(
        &self,
        push_mod: &str,
        hostnames: &str,
        v4_num: u32,
        v6_num: u32,
        ip_type: &str,
        ddns_name: &str,
        ips: &[String],
        domains: &[String],
        add_ddns: &str,
        cf_command: &str,
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

        #[cfg(target_os = "linux")] clien: &str,
    ) -> Result<()> {
        let (domains, hostnames) = if add_ddns != "未指定" {
            let list: Vec<String> = hostname2
                .split_whitespace()
                .map(|sub| format!("{}.{}", sub, hostname1))
                .collect();
            let joined = list.join(" ");
            (list, joined)
        } else {
            (Vec::new(), String::new())
        };

        crate::print_section_header("插件暂停");

        #[cfg(target_os = "linux")]
        let plugin_status = self.control_plugin(clien, "stop")?;

        #[cfg(not(target_os = "linux"))]
        {
            crate::info_println(format_args!("当前系统不需要处理插件"));
        }

        let output_file = super::utils::parse_cf_command_for_file(cf_command, "-f");

        let is_force_read_mode = v4_num == 0 && v6_num == 0;

        if is_force_read_mode {
            crate::info_println(format_args!(
                "IPv4和IPv6所需数量都设为0，跳过测速并直接推送消息"
            ));
        }

        let handle_ip_process = |ip_type: &str, url: &str, num: u32| -> Result<()> {
            if !is_force_read_mode && num == 0 {
                crate::info_println(format_args!("根据设置，跳过 {} 测速", ip_type));
                return Ok(());
            }

            let ips = if is_force_read_mode {
                self.read_ips_from_csv(ip_type, 0, cf_command)?
            } else {
                let (fetched_ips, _) = self.process_ip_type(
                    ip_type,
                    url,
                    num,
                    cf_command,
                    add_ddns,
                    x_email,
                    zone_id,
                    api_key,
                    &domains,
                    output_file.as_deref(),
                    #[cfg(target_os = "linux")]
                    plugin_status.as_deref(),
                    #[cfg(target_os = "linux")]
                    clien,
                )?;
                fetched_ips
            };

            self.push_ips(
                push_mod, &hostnames, v4_num, v6_num, ip_type, ddns_name, &ips, &domains, add_ddns,
                cf_command,
            )?;

            Ok(())
        };

        handle_ip_process("IPv4", v4_url, v4_num)?;
        handle_ip_process("IPv6", v6_url, v6_num)?;

        #[cfg(target_os = "linux")]
        if clien != "未指定" && !clien.is_empty() {
            if let Some("stopped") = plugin_status {
                crate::print_section_header("插件恢复");
                self.control_plugin(clien, "start")?;
            }
        }

        Ok(())
    }

    #[cfg(target_os = "linux")]
    fn control_plugin(&self, clien: &str, action: &str) -> Result<Option<&'static str>> {
        if clien == "未指定" || clien.is_empty() {
            crate::info_println(format_args!("按配置不{}插件", action));
            return Ok(None);
        }

        let action_desc = match action {
            "stop" => "停止",
            "start" => "恢复",
            "restart" => "重启",
            _ => "操作",
        };

        crate::info_println(format_args!("正在{}插件 {}", action_desc, clien));

        let status = Command::new(format!("/etc/init.d/{}", clien))
            .arg(action)
            .status();

        let success = status.map(|s| s.success()).unwrap_or(false);

        if success {
            crate::info_println(format_args!("已{}插件 {}", action_desc, clien));
            if action == "stop" {
                Ok(Some("stopped"))
            } else {
                Ok(None)
            }
        } else {
            crate::error_println(format_args!("{}插件 {} 失败", action_desc, clien));
            Ok(None)
        }
    }

    fn push_ips(
        &self,
        push_mod: &str,
        hostnames: &str,
        v4_num: u32,
        v6_num: u32,
        ip_type: &str,
        ddns_name: &str,
        ips: &[String],
        domains: &[String],
        add_ddns: &str,
        cf_command: &str,
    ) -> Result<()> {
        if !ips.is_empty() {
            let params = super::start_struct::PushParams {
                push_mod,
                hostnames,
                v4_num,
                v6_num,
                ip_type,
                ddns_name,
                ips,
                domains,
                add_ddns,
                csvfile: cf_command,
            };
            self.execute_push(params)?;
        }
        Ok(())
    }
}