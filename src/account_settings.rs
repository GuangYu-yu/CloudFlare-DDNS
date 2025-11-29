use crate::{Account, Config, Settings, UIComponents, clear_screen, impl_settings};
use anyhow::Result;
use std::path::{Path, PathBuf};

// 独立函数，用于获取账户输入
pub fn get_account_input(
    ui: &UIComponents,
    config: &Config,
    default_values: Option<&Account>,
) -> Result<Option<Account>> {
    clear_screen()?;

    // 输入账户组名称
    let account_name: String = if let Some(defaults) = default_values {
        loop {
            let name = ui.get_text_input(
                "请输入新的账户组名称",
                &defaults.account_name,
                |input| !input.trim().is_empty(),
            )?;

            // 如果名称没有改变，直接使用
            if name == defaults.account_name {
                break name;
            }

            // 检查账户组名称是否已存在
            if config.account.iter().any(|a| a.account_name == name) {
                ui.show_error("已有该账户组名称！请重新输入。")?;
                continue;
            }

            break name;
        }
    } else {
        let name = ui.get_text_input(
            "请输入自定义账户组名称（留空返回上级）",
            "",
            |input| {
                if input.trim().is_empty() {
                    return true; // 允许空输入，由调用方处理
                }
                if input == "0" {
                    return false; // 不允许设置为0
                }
                if !input.chars().all(|c| c.is_ascii_alphanumeric() || c == '_') {
                    return false; // 只允许字母、数字和下划线
                }
                true
            },
        )?;

        if name.trim().is_empty() {
            return Ok(None);
        }

        // 检查账户组名称是否已存在
        if config.account.iter().any(|a| a.account_name == name) {
            ui.show_error("已有该账户组名称！")?;
            return Ok(None);
        }
        name
    };

    let x_email = ui.get_email_input(
        "请输入账户登陆邮箱",
        default_values.map(|d| d.x_email.as_str()).unwrap_or(""),
    )?;

    let zone_id = ui.get_non_empty_input_with_default(
        "请输入区域ID",
        default_values.map(|d| d.zone_id.as_str()).unwrap_or(""),
    )?;

    let api_key = ui.get_non_empty_input_with_default(
        "请输入API Key",
        default_values.map(|d| d.api_key.as_str()).unwrap_or(""),
    )?;

    Ok(Some(Account {
        account_name,
        x_email,
        zone_id,
        api_key,
    }))
}

pub struct AccountSettings {
    config_path: PathBuf,
    config: Config,
    ui: UIComponents,
}

impl AccountSettings {
    pub fn new(config_path: &Path) -> Result<Self> {
        let mut settings = AccountSettings {
            config_path: config_path.to_path_buf(),
            config: Config::default(),
            ui: UIComponents::new(),
        };
        settings.load_config()?;
        Ok(settings)
    }

    pub fn run(&mut self) -> Result<()> {
        loop {
            clear_screen()?;
            self.list_accounts()?;

            let items = ["添加账户", "删除账户", "修改账户"];

            let selection = match self.ui.show_menu("账户设置（按ESC返回上级）", &items, 0)?
            {
                Some(value) => value,
                None => return Ok(()),
            };

            match selection {
                0 => self.add_account()?,
                1 => self.delete_account()?,
                2 => self.modify_account()?,
                _ => unreachable!(),
            }
        }
    }

    fn list_accounts(&self) -> Result<()> {
        if self.config.account.is_empty() {
            self.ui.show_message("(暂未设置账户组)")?;
        } else {
            let account_info = self
                .config
                .account
                .iter()
                .map(|acc| {
                    format!(
                        "- 账户组: {}\n  邮箱: {}\n  区域ID: {}\n  API Key: {}",
                        acc.account_name, acc.x_email, acc.zone_id, acc.api_key
                    )
                })
                .collect::<Vec<String>>();
            self.ui.show_info_list("", &account_info)?;
        }
        Ok(())
    }

    fn add_account(&mut self) -> Result<()> {
        let account = match get_account_input(&self.ui, &self.config, None)? {
            Some(acc) => acc,
            None => return Ok(()),
        };

        self.config.account.push(account);

        self.config.save(self.config_path.as_path())?;
        self.ui.show_success("账户添加成功！")?;
        clear_screen()?;
        Ok(())
    }
    fn delete_account(&mut self) -> Result<()> {
        if self.config.account.is_empty() {
            self.ui.show_error("没有可删除的账户！")?;
            return Ok(());
        }

        self.ui.show_message("删除账户")?;

        let account_names: Vec<&str> = self
            .config
            .account
            .iter()
            .map(|a| a.account_name.as_str())
            .collect();

        let selection =
            match self
                .ui
                .show_menu("选择要删除的账户（按ESC返回上级）", &account_names, 0)?
            {
                Some(value) => value,
                None => return Ok(()),
            };

        let confirm = self.ui.confirm(
            &format!(
                "确定要删除账户 '{}' 吗？（按ESC返回上级）",
                account_names[selection]
            ),
            false,
        )?;

        if confirm {
            self.config.account.remove(selection);
            self.config.save(self.config_path.as_path())?;
            self.ui.show_success("账户删除成功！")?;
        } else {
            self.ui.show_message("已取消删除操作。")?;
        }

        clear_screen()?;
        Ok(())
    }

    fn modify_account(&mut self) -> Result<()> {
        if self.config.account.is_empty() {
            self.ui.show_error("没有可修改的账户！")?;
            return Ok(());
        }

        self.ui.show_message("修改账户")?;

        let account_names: Vec<&str> = self
            .config
            .account
            .iter()
            .map(|a| a.account_name.as_str())
            .collect();

        let selection =
            match self
                .ui
                .show_menu("选择要修改的账户（按ESC返回上级）", &account_names, 0)?
            {
                Some(value) => value,
                None => return Ok(()),
            };

        let selection_index = selection;
        let current_account_name = self.config.account[selection_index].account_name.clone();

        self.ui.show_message("当前账户信息：")?;
        self.ui.show_message(&format!(
            "账户组: {}",
            self.config.account[selection_index].account_name
        ))?;
        self.ui.show_message(&format!(
            "邮箱: {}",
            self.config.account[selection_index].x_email
        ))?;
        self.ui.show_message(&format!(
            "区域ID: {}",
            self.config.account[selection_index].zone_id
        ))?;
        self.ui.show_message(&format!(
            "API Key: {}",
            self.config.account[selection_index].api_key
        ))?;
        self.ui.show_message("")?;
        clear_screen()?;

        let account = match get_account_input(
            &self.ui,
            &self.config,
            Some(&self.config.account[selection_index]),
        )? {
            Some(acc) => acc,
            None => return Ok(()),
        };

        // 保存新的账户组名称
        let new_account_name = account.account_name;

        let account_ref = &mut self.config.account[selection_index];
        account_ref.account_name = new_account_name.clone();
        account_ref.x_email = account.x_email;
        account_ref.zone_id = account.zone_id;
        account_ref.api_key = account.api_key;

        // 如果账户组名称已更改，则更新所有相关的解析组
        if new_account_name != current_account_name
            && let Some(resolves) = &mut self.config.resolve
        {
            for resolve in resolves {
                if resolve.add_ddns == current_account_name {
                    resolve.add_ddns = new_account_name.clone();
                }
            }
        }

        self.config.save(self.config_path.as_path())?;
        self.ui.show_success("账户修改成功！")?;
        clear_screen()?;
        Ok(())
    }
}

impl_settings!(AccountSettings);