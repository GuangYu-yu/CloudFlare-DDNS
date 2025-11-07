use crate::push::PushService;
use crate::{Config, Resolve, Settings, UIComponents, clear_screen, impl_settings, error_println};
use anyhow::Result;
use std::path::PathBuf;

pub struct Start {
    config_path: PathBuf,
    config: Config,
    ui: UIComponents,
}

impl Start {
    pub fn new(config_path: PathBuf) -> Result<Self> {
        let mut settings = Start {
            config_path: config_path.to_path_buf(),
            config: Config::default(),
            ui: UIComponents::new(),
        };
        settings.load_config()?;
        Ok(settings)
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
                error_println(format_args!("未找到任何解析配置"));
                self.ui.pause("")?;
                break;
            }

            let items: Vec<String> = resolves.iter().map(|r| r.ddns_name.to_string()).collect();
            let items_ref: Vec<&str> = items.iter().map(|s| s.as_str()).collect();

            let selection =
                match self
                    .ui
                    .show_menu("请选择解析组（按ESC返回上级）", &items_ref, 0)?
                {
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
        Ok(self.config.resolve.as_ref().cloned().unwrap_or_default())
    }

    fn execute_resolve_by_name(&mut self, ddns_name: &str) -> Result<()> {
        let resolves = self.get_resolves()?;
        let resolve = resolves
            .iter()
            .find(|r| r.ddns_name == ddns_name)
            .ok_or_else(|| anyhow::anyhow!("未找到指定的解析组: {}", ddns_name))?;

        self.execute_resolve(resolve)?;
        Ok(())
    }

    fn execute_resolve(&self, resolve: &Resolve) -> Result<()> {
        // 获取账户信息
        let (x_email, zone_id, api_key) = if resolve.add_ddns != "未指定" {
            let account = self
                .config
                .account
                .iter()
                .find(|a| a.account_name == resolve.add_ddns)
                .ok_or_else(|| anyhow::anyhow!("未找到指定的账户: {}", resolve.add_ddns))?;
            (&account.x_email, &account.zone_id, &account.api_key)
        } else {
            (&String::new(), &String::new(), &String::new())
        };

        // 获取插件配置
        #[cfg(target_os = "linux")]
        let default_clien = "未指定".to_string();
        
        #[cfg(target_os = "linux")]
        let clien = self
            .config
            .plugin
            .as_ref()
            .map(|p| p.clien.as_str())
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

            #[cfg(target_os = "linux")]
            clien,

        )?;

        Ok(())
    }

    /// 执行消息推送的统一封装
    pub fn execute_push(
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
        csvfile: &str,
    ) -> Result<()> {
        if !push_mod.is_empty() && push_mod != "不设置" {
            // 使用 create_domain_ip_mapping 创建域名和IP的映射关系
            let domain_ip_mapping = super::utils::create_domain_ip_mapping(ips, domains, add_ddns);

            self.run_push(
                push_mod,
                hostnames,
                v4_num,
                v6_num,
                ip_type,
                &super::utils::get_result_csv_path(csvfile),
                ddns_name,
                &domain_ip_mapping,
            )?;
        }
        Ok(())
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
        domain_ip_mapping: &[(String, String)],
    ) -> Result<()> {
        let push_service = PushService::new(&self.config_path)?;
        push_service.run_push(
            push_mod,
            hostnames,
            v4_num,
            v6_num,
            ip_type,
            csvfile,
            ddns_name,
            domain_ip_mapping,
        )?;

        Ok(())
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

        #[cfg(target_os = "linux")]
        clien: &str,

    ) -> Result<()> {
        // 委托给 DdnsOperations 模块处理
        <super::start_struct::Start as super::ddns_operations::DdnsOperations>::run_start_ddns(
            self,
            add_ddns,
            ddns_name,
            x_email,
            zone_id,
            api_key,
            hostname1,
            hostname2,
            v4_num,
            v6_num,
            cf_command,
            v4_url,
            v6_url,
            push_mod,
            #[cfg(target_os = "linux")]
            clien,
        )
    }
}

impl_settings!(Start);