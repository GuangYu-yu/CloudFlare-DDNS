use super::ddns_operations::DdnsOperations;
use super::utils::{create_domain_ip_mapping, get_result_csv_path};
use crate::push::PushService;
use crate::{Config, Resolve, Settings, UIComponents, clear_screen, error_println, impl_settings};
use anyhow::Result;
use std::path::{Path, PathBuf};

// 为execute_push函数创建参数结构体
pub struct PushParams<'a> {
    pub push_mod: &'a str,
    pub hostnames: &'a str,
    pub v4_num: u32,
    pub v6_num: u32,
    pub ip_type: &'a str,
    pub ddns_name: &'a str,
    pub ips: &'a [String],
    pub domains: &'a [String],
    pub add_ddns: &'a str,
    pub csvfile: &'a str,
}

// 为run_push函数创建参数结构体
struct RunPushParams<'a> {
    push_mod: &'a str,
    hostnames: &'a str,
    v4_num: u32,
    v6_num: u32,
    ip_type: &'a str,
    csvfile: &'a str,
    ddns_name: &'a str,
    domain_ip_mapping: &'a [(String, String)],
}

pub struct Start {
    config_path: PathBuf,
    config: Config,
    ui: UIComponents,
    push_service: PushService,
}

impl Start {
    pub fn new(config_path: &Path) -> Result<Self> {
        let config_path_buf = config_path.to_path_buf();
        let mut settings = Start {
            config_path: config_path_buf.clone(),
            config: Config::default(),
            ui: UIComponents::new(),
            push_service: PushService::new(&config_path_buf)?,
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
        clear_screen()?;

        let resolves = self.get_resolves();
        if resolves.is_empty() {
            error_println(format_args!("未找到任何解析配置"));
            self.ui.pause("")?;
            return Ok(());
        }

        let items_ref = resolves
            .iter()
            .map(|r| r.ddns_name.as_str())
            .collect::<Vec<_>>();

        let selection = match self
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

        Ok(())
    }

    fn get_resolves(&self) -> Vec<Resolve> {
        self.config.resolve.clone().unwrap_or_default()
    }

    fn execute_resolve_by_name(&mut self, ddns_name: &str) -> Result<()> {
        let resolve = self
            .config
            .resolve
            .as_ref()
            .ok_or_else(|| anyhow::anyhow!("未找到任何解析组"))?
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
            // 将 &String 转换为 &str，与 else 分支的类型匹配
            (
                account.x_email.as_str(),
                account.zone_id.as_str(),
                account.api_key.as_str(),
            )
        } else {
            // 使用静态空字符串，避免悬垂引用
            ("", "", "")
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
    pub fn execute_push(&self, params: PushParams) -> Result<()> {
        if !params.push_mod.is_empty() && params.push_mod != "不设置" {
            // 使用 create_domain_ip_mapping 创建域名和IP的映射关系
            let domain_ip_mapping =
                create_domain_ip_mapping(params.ips, params.domains, params.add_ddns);

            let run_push_params = RunPushParams {
                push_mod: params.push_mod,
                hostnames: params.hostnames,
                v4_num: params.v4_num,
                v6_num: params.v6_num,
                ip_type: params.ip_type,
                csvfile: &get_result_csv_path(params.csvfile),
                ddns_name: params.ddns_name,
                domain_ip_mapping: &domain_ip_mapping,
            };

            self.run_push(run_push_params)?;
        }
        Ok(())
    }

    fn run_push(&self, params: RunPushParams) -> Result<()> {
        self.push_service.run_push(
            params.push_mod,
            params.hostnames,
            params.v4_num,
            params.v6_num,
            params.ip_type,
            params.csvfile,
            params.ddns_name,
            params.domain_ip_mapping,
        )?;

        Ok(())
    }
}

impl_settings!(Start);