use crate::{Config, Resolve, Settings, clear_screen, impl_settings, ui_components::UIComponents, CLOUDFLAREST_RUST};
use anyhow::Result;
use regex::Regex;
use std::path::PathBuf;

pub struct ResolveSettings {
    config_path: PathBuf,
    config: Config,
    ui: UIComponents,
    domain_regex: Regex,
}

impl ResolveSettings {
    pub fn new(config_path: PathBuf) -> Result<Self> {
        let mut settings = ResolveSettings {
            config_path: config_path.clone(),
            config: Config::default(),
            ui: UIComponents::new(),
            domain_regex: Regex::new(r"^[a-zA-Z0-9\u{4e00}-\u{9fa5}.\-]+$").unwrap(),
        };
        settings.load_config()?;
        Ok(settings)
    }

    pub fn run(&mut self) -> Result<()> {
        loop {
            clear_screen()?;

            let items = ["查看解析", "添加解析", "删除解析", "修改解析"];

            let selection = self.ui.show_menu("解析设置（按ESC返回上级）", &items, 0)?;

            // 如果用户按ESC返回，则直接返回
            let selection = match selection {
                Some(value) => value,
                None => return Ok(()),
            };

            match selection {
                0 => self.view_resolves()?,
                1 => self.add_resolve()?,
                2 => self.delete_resolve()?,
                3 => self.modify_resolve()?,
                _ => unreachable!(),
            }
        }
    }

    fn view_resolves(&self) -> Result<()> {
        clear_screen()?;

        if let Some(resolves) = &self.config.resolve {
            let info_list: Vec<String> = resolves.iter().enumerate().map(|(i, r)| {
                format!(
                    "\n[{}] 账户组：{}\n    解析组：{}\n    一级域名：{}\n    二级域名：{}\n    IPv4数量：{}\n    IPv6数量：{}\n    CloudflareST命令：{}\n    IPv4地址URL：{}\n    IPv6地址URL：{}\n    推送方式：{}",
                    i + 1, r.add_ddns, r.ddns_name, r.hostname1, r.hostname2, r.v4_num, r.v6_num,
                    r.cf_command, r.v4_url, r.v6_url, r.push_mod
                )
            }).collect();

            self.ui.show_info_list("解析组信息", &info_list)?;
        } else {
            self.ui.show_message("当前无解析组配置")?;
        }

        self.ui.pause("按回车键继续...")?;
        clear_screen()?;
        Ok(())
    }

    fn look_cfst_rules(&self) -> anyhow::Result<()> {
        let lines: Vec<String> = [
            "    示例：-n 500 -tll 20 -tl 300 -sl 15 -tp 2053 -t 8 -tlr 0.2",
            "    HTTP  端口  80  8080 2052 2082 2086 2095 8880",
            "    HTTPS 端口  443 8443 2053 2083 2087 2096",
            "    -n 200      延迟测速线程",
            "    -t 4        延迟测速次数",
            "    -dt 10      下载测速时间",
            "    -tp 443     指定测速端口",
            "    -url <URL>  指定测速地址",
            "    -tl 200     平均延迟上限",
            "    -tll 40     平均延迟下限",
            "    -tlr 0.2    丢包几率上限",
            "    -sl 5       下载速度下限",
            "    -dd         禁用下载测速",
            "    -all4       测速全部的IP",
        ]
        .iter()
        .map(|s| s.to_string())
        .collect();

        self.ui.show_info_list("CloudflareST 参数说明", &lines)?;
        Ok(())
    }

    fn get_resolve_input(
        &mut self,
        default_values: Option<&Resolve>,
    ) -> anyhow::Result<Option<Resolve>> {
        clear_screen()?;

        // 显示现有账户
        if self.config.account.is_empty() {
            self.ui.show_message("(无已设置的账户信息)")?;
        } else {
            let account_list: Vec<String> = self
                .config
                .account
                .iter()
                .map(|acc| format!("- 账户组: {}", acc.account_name))
                .collect();
            self.ui.show_info_list("现有账户", &account_list)?;
        }

        // 账户组输入
        let add_ddns = loop {
            let input = self.ui.get_text_input(
                "请输入账户组名称（输入0不指定账户组，留空则返回上级）",
                "",
                |_| true, // 允许任何输入
            )?;

            if input.trim().is_empty() {
                return Ok(None); // 返回上级
            } else if input.trim() == "0" {
                break "未指定".to_string();
            } else if !self.config.account.iter().any(|a| a.account_name == input) {
                self.ui.show_error("账户组不存在")?;
                continue;
            } else {
                break input;
            }
        };

        // 解析组名称输入
        let ddns_name = loop {
            let default_name = default_values.map(|d| d.ddns_name.as_str()).unwrap_or("");

            let input = self.ui.get_text_input(
                "请输入自定义解析组名称（只能包含字母、数字和下划线）",
                default_name,
                |input| Regex::new(r"^[A-Za-z0-9_]+$").unwrap().is_match(input),
            )?;

            if !Regex::new(r"^[A-Za-z0-9_]+$")?.is_match(&input) {
                self.ui.show_error("只能包含字母、数字和下划线")?;
                continue;
            } else if let Some(resolves) = &self.config.resolve {
                // 检查名称是否已存在（排除当前正在修改的解析组）
                let current_ddns_name = default_values.map(|d| &d.ddns_name);
                if resolves
                    .iter()
                    .any(|r| r.ddns_name == input && Some(&r.ddns_name) != current_ddns_name)
                {
                    self.ui.show_error("已有该解析组名称！")?;
                    continue;
                }
            }
            break input;
        };

        // 如果账户组为 "未指定"，跳过域名设置
        let (hostname1, hostname2) = if add_ddns == "未指定" {
            (String::new(), String::new())
        } else {
            let hostname1 = loop {
                let default_hostname1 = default_values.map(|d| d.hostname1.as_str()).unwrap_or("");

                let input = self.ui.get_text_input(
                    "请输入要解析的一级域名（留空则返回上级）",
                    default_hostname1,
                    |input| input.trim().is_empty() || self.domain_regex.is_match(input),
                )?;

                if input.trim().is_empty() && default_values.is_none() {
                    return Ok(None);
                }
                if input.trim().is_empty() && default_values.is_some() {
                    break default_hostname1.to_string();
                }
                if self.domain_regex.is_match(&input) {
                    break input;
                } else {
                    self.ui.show_error("格式不正确")?;
                }
            };

            let hostname2 = loop {
                let default_hostname2 = default_values.map(|d| d.hostname2.as_str()).unwrap_or("");

                let input = self.ui.get_text_input(
                    "请输入一个或多个二级域名（不含一级域名，多个则以空格分隔）",
                    default_hostname2,
                    |input| {
                        if input.trim().is_empty() && default_values.is_some() {
                            return true;
                        }
                        input
                            .split_whitespace()
                            .all(|s| self.domain_regex.is_match(s))
                    },
                )?;

                if input.trim().is_empty() && default_values.is_none() {
                    self.ui.show_error("格式不正确")?;
                    continue;
                }
                if input.trim().is_empty() && default_values.is_some() {
                    break default_hostname2.to_string();
                }

                let all_valid = input
                    .split_whitespace()
                    .all(|s| self.domain_regex.is_match(s));

                if all_valid {
                    break input;
                } else {
                    self.ui.show_error("格式不正确")?;
                }
            };

            (hostname1, hostname2)
        };

        // IPv4数量
        let v4_num = loop {
            let default_v4 = default_values
                .map(|d| d.v4_num.to_string())
                .unwrap_or_else(|| "0".to_string());

            let input = self.ui.get_text_input(
                "请输入IPv4解析数量（可设置为0）",
                &default_v4,
                |input| input.trim().is_empty() || input.trim().parse::<u32>().is_ok(),
            )?;

            if input.trim().is_empty() && default_values.is_none() {
                break 0;
            }
            if let Ok(num) = input.trim().parse::<u32>() {
                break num;
            } else {
                self.ui.show_error("格式不正确")?;
            }
        };

        // IPv6数量
        let v6_num = loop {
            let default_v6 = default_values
                .map(|d| d.v6_num.to_string())
                .unwrap_or_else(|| "0".to_string());

            let input = self.ui.get_text_input(
                "请输入IPv6解析数量（可设置为0）",
                &default_v6,
                |input| input.trim().is_empty() || input.trim().parse::<u32>().is_ok(),
            )?;

            if input.trim().is_empty() && default_values.is_none() {
                break 0;
            }
            if let Ok(num) = input.trim().parse::<u32>() {
                break num;
            } else {
                self.ui.show_error("格式不正确")?;
            }
        };

        // CloudflareST 示例输出
        self.look_cfst_rules()?;

        // CloudflareST 命令输入
        let cf_command = loop {
            let default_cf = default_values.map(|d| d.cf_command.as_str()).unwrap_or("");

            let input = self.ui.get_text_input(
                #[cfg(target_os = "windows")]
                &format!("请输入CloudflareST传入参数（无需以\".\\{}\"开头）", CLOUDFLAREST_RUST),

                #[cfg(any(target_os = "linux", target_os = "macos"))]
                &format!("请输入CloudflareST传入参数（无需以\"./{}\"开头）", CLOUDFLAREST_RUST),
                default_cf,
                |_| true, // 允许任何输入
            )?;

            if input.trim().is_empty() && default_values.is_none() {
                break String::new();
            }
            if !input.trim().is_empty() {
                break input;
            } else {
                break default_cf.to_string();
            }
        };

        let url_regex = Regex::new(r"^https?://").unwrap();

        // URL 读取 IPv4
        let v4_url = loop {
            let input = self
                .ui
                .get_text_input("从URL链接获取IPv4地址", "", |input| {
                    input.is_empty() || url_regex.is_match(input)
                })?;

            if input.is_empty() || url_regex.is_match(&input) {
                break input;
            } else {
                self.ui.show_error("格式不正确")?;
                continue;
            }
        };

        // URL 读取 IPv6
        let v6_url = loop {
            let input = self
                .ui
                .get_text_input("从URL链接获取IPv6地址", "", |input| {
                    input.is_empty() || url_regex.is_match(input)
                })?;

            if input.is_empty() || url_regex.is_match(&input) {
                break input;
            } else {
                self.ui.show_error("格式不正确")?;
            }
        };

        // 推送方式
        let push_options = [
            "Telegram",
            "PushPlus",
            "Server酱",
            "PushDeer",
            "企业微信",
            "Synology-Chat",
            "Github",
        ];

        // 设置默认选择
        let default_selections = if let Some(defaults) = default_values {
            let mut selections = vec![false; push_options.len()];
            for (i, option) in push_options.iter().enumerate() {
                if defaults.push_mod.contains(option) {
                    selections[i] = true;
                }
            }
            selections
        } else {
            vec![false; push_options.len()]
        };

        let selections = self.ui.show_multi_select(
            "使用空格选中所需的推送方式，按回车确认：",
            &push_options,
            &default_selections,
        )?;

        let push_mod = if selections.is_empty() {
            "不设置".to_string()
        } else {
            let selected_options: Vec<String> = selections
                .iter()
                .map(|i| push_options[*i].to_string())
                .collect();
            selected_options.join(" ")
        };

        // 创建解析配置
        let resolve = Resolve {
            add_ddns,
            ddns_name: ddns_name.clone(),
            hostname1,
            hostname2,
            v4_num,
            v6_num,
            cf_command,
            v4_url,
            v6_url,
            push_mod,
        };

        Ok(Some(resolve))
    }

    fn add_resolve(&mut self) -> anyhow::Result<()> {
        clear_screen()?;

        let resolve = match self.get_resolve_input(None)? {
            Some(resolve) => resolve,
            None => return Ok(()), // 用户选择返回上级，直接返回
        };

        // 添加到配置中
        if let Some(resolves) = &mut self.config.resolve {
            resolves.push(resolve);
        } else {
            self.config.resolve = Some(vec![resolve]);
        }

        // 保存配置
        self.config.save(&self.config_path)?;
        self.ui.show_success("解析条目添加成功！")?;
        clear_screen()?;
        Ok(())
    }

    fn delete_resolve(&mut self) -> Result<()> {
        let name_to_delete = {
            if self.config.resolve.is_none() || self.config.resolve.as_ref().unwrap().is_empty() {
                self.ui.show_message("没有可删除的解析！")?;
                self.ui.pause("按回车键继续...")?;
                clear_screen()?;
                return Ok(());
            }

            // 显示现有解析
            let resolve_names = self
                .config
                .resolve
                .as_ref()
                .unwrap()
                .iter()
                .map(|r| r.ddns_name.as_str())
                .collect::<Vec<&str>>();

            clear_screen()?;

            let selection =
                self.ui
                    .show_menu("选择要删除的解析组（按ESC返回上级）", &resolve_names, 0)?;

            // 如果用户按ESC返回，则直接返回
            let selection = match selection {
                Some(value) => value,
                None => return Ok(()),
            };

            resolve_names[selection].to_string()
        };

        let confirm = self.ui.show_menu(
            &format!("确认删除解析组 {} 吗？", name_to_delete),
            &["是", "否"],
            1,
        )?;

        if confirm == Some(0) {
            let resolves = self.config.resolve.as_mut().unwrap();
            resolves.retain(|r| r.ddns_name != name_to_delete);
            // 如果没有剩余的解析组，删除 resolve 键
            if resolves.is_empty() {
                self.config.resolve = None;
            }
            self.config.save(&self.config_path)?;
            self.ui
                .show_success(&format!("解析组 {} 已成功删除！", name_to_delete))?;
        } else {
            self.ui.show_message("已取消删除操作。")?;
        }

        clear_screen()?;
        Ok(())
    }

    fn modify_resolve(&mut self) -> Result<()> {
        if self.config.resolve.is_none() || self.config.resolve.as_ref().unwrap().is_empty() {
            self.ui.show_message("没有可修改的解析！")?;
            self.ui.pause("按回车键继续...")?;
            clear_screen()?;
            return Ok(());
        }

        // 显示现有解析
        let resolve_items: Vec<String> = self
            .config
            .resolve
            .as_ref()
            .unwrap()
            .iter()
            .map(|r| format!("账户组：{} | 解析组：{}", r.add_ddns, r.ddns_name))
            .collect();

        let resolve_items_refs: Vec<&str> = resolve_items.iter().map(|s| s.as_str()).collect();

        let selection =
            self.ui
                .show_menu("选择要修改的解析组（按ESC返回上级）", &resolve_items_refs, 0)?;

        // 如果用户按ESC返回，则直接返回
        let selection = match selection {
            Some(value) => value,
            None => return Ok(()),
        };

        let selected_index = selection;
        let current_resolve = &self.config.resolve.as_ref().unwrap()[selected_index].clone();

        // 使用通用函数获取新的解析配置
        let new_resolve = match self.get_resolve_input(Some(current_resolve))? {
            Some(resolve) => resolve,
            None => return Ok(()), // 用户选择返回上级，直接返回
        };

        // 更新配置
        {
            let resolves = self.config.resolve.as_mut().unwrap();
            resolves[selected_index] = new_resolve;
        }

        // 保存配置
        self.config.save(&self.config_path)?;
        self.ui.show_success("解析信息修改成功！")?;
        clear_screen()?;
        Ok(())
    }
}

impl_settings!(ResolveSettings);