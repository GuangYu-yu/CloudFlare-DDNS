use anyhow::Result;
use console::Term;
use dialoguer::{Input, MultiSelect, Select, theme::ColorfulTheme};
use regex::Regex;
use std::fmt::Display;

/// 通用UI组件，提供统一的用户交互界面
pub struct UIComponents {
    pub theme: ColorfulTheme,
    pub term: Term,
    pub email_regex: Regex,
}

impl UIComponents {
    /// 创建新的UI组件实例
    pub fn new() -> Self {
        Self {
            theme: ColorfulTheme::default(),
            term: Term::stderr(),
            email_regex: Regex::new(r"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$").unwrap(),
        }
    }

    /// 显示菜单并获取用户选择
    pub fn show_menu(&self, prompt: &str, items: &[&str], default: usize) -> Result<Option<usize>> {
        let selection = Select::with_theme(&self.theme)
            .with_prompt(prompt)
            .items(items)
            .default(default)
            .interact_opt()?;

        Ok(selection)
    }

    pub fn show_menu_with_display<T: Display>(
        &self,
        prompt: &str,
        items: &[T],
        default: usize,
    ) -> Result<Option<usize>> {
        let items_str: Vec<String> = items.iter().map(|item| format!("{}", item)).collect();
        let items_ref: Vec<&str> = items_str.iter().map(|s| s.as_str()).collect();

        self.show_menu(prompt, &items_ref, default)
    }

    /// 显示确认对话框
    pub fn confirm(&self, prompt: &str, default_yes: bool) -> Result<bool> {
        let items = ["是", "否"];
        let default = if default_yes { 0 } else { 1 };

        let selection = Select::with_theme(&self.theme)
            .with_prompt(prompt)
            .items(&items)
            .default(default)
            .interact_opt()?;

        match selection {
            Some(0) => Ok(true),
            Some(_) => Ok(false),
            None => Ok(false), // ESC键视为取消
        }
    }

    /// 获取文本输入，支持默认值和验证
    pub fn get_text_input<F>(&self, prompt: &str, default: &str, validator: F) -> Result<String>
    where
        F: Fn(&str) -> bool,
    {
        loop {
            let input: String = Input::with_theme(&self.theme)
                .with_prompt(prompt)
                .default(default.to_string())
                .interact_text()?;

            if validator(&input) {
                return Ok(input);
            } else {
                self.term.write_line("输入格式不正确，请重新输入")?;
                self.term.read_key()?;
            }
        }
    }

    /// 获取文本输入，支持默认值，不需要验证
    pub fn get_text_input_simple(&self, prompt: &str, default: &str) -> Result<String> {
        let input: String = Input::with_theme(&self.theme)
            .with_prompt(prompt)
            .default(default.to_string())
            .interact_text()?;
        Ok(input)
    }

    /// 获取邮箱输入，自动验证邮箱格式
    pub fn get_email_input(&self, prompt: &str, default: &str) -> Result<String> {
        self.get_text_input(prompt, default, |input| {
            !input.trim().is_empty() && self.email_regex.is_match(input)
        })
    }

    /// 获取非空输入
    pub fn get_non_empty_input(&self, prompt: &str, default: &str) -> Result<String> {
        self.get_text_input(prompt, default, |input| !input.trim().is_empty())
    }

    /// 获取URL输入，验证URL格式
    pub fn get_url_input(&self, prompt: &str, allow_empty: bool) -> Result<String> {
        let url_regex = Regex::new(r"^https?://").unwrap();

        loop {
            let input: String = if allow_empty {
                Input::with_theme(&self.theme)
                    .with_prompt(prompt)
                    .allow_empty(true)
                    .interact_text()?
            } else {
                Input::with_theme(&self.theme)
                    .with_prompt(prompt)
                    .interact_text()?
            };

            if (input.is_empty() && allow_empty) || url_regex.is_match(&input) {
                return Ok(input);
            } else {
                self.term
                    .write_line("URL格式不正确，必须以http://或https://开头")?;
                self.term.read_key()?;
            }
        }
    }

    /// 显示多选菜单
    pub fn show_multi_select(&self, prompt: &str, items: &[&str], defaults: &[bool]) -> Result<Vec<usize>> {
        let selections = MultiSelect::with_theme(&self.theme)
            .with_prompt(prompt)
            .items(items)
            .defaults(defaults)
            .interact()?;

        Ok(selections)
    }

    /// 显示多选菜单
    pub fn show_multi_select_with_display<T: Display>(
        &self,
        prompt: &str,
        items: &[T],
        defaults: &[bool],
    ) -> Result<Vec<usize>> {
        let items_str: Vec<String> = items.iter().map(|item| format!("{}", item)).collect();
        let items_ref: Vec<&str> = items_str.iter().map(|s| s.as_str()).collect();

        self.show_multi_select(prompt, &items_ref, defaults)
    }

    /// 显示消息并等待用户按键
    pub fn pause(&self, message: &str) -> Result<()> {
        self.term.write_line(message)?;
        self.term.read_line()?;
        Ok(())
    }

    /// 显示消息
    pub fn show_message(&self, message: &str) -> Result<()> {
        self.term.write_line(message)?;
        Ok(())
    }

    /// 显示错误消息并等待用户按键
    pub fn show_error(&self, message: &str) -> Result<()> {
        self.term.write_line(&format!("错误: {}", message))?;
        self.term.read_key()?;
        Ok(())
    }

    /// 显示成功消息并等待用户按键
    pub fn show_success(&self, message: &str) -> Result<()> {
        self.term.write_line(&format!("成功: {}", message))?;
        self.term.read_key()?;
        Ok(())
    }

    /// 显示信息列表
    pub fn show_info_list(&self, title: &str, items: &[String]) -> Result<()> {
        if !title.is_empty() {
            self.term.write_line(title)?;
        }

        if items.is_empty() {
            self.term.write_line("暂无数据")?;
        } else {
            for item in items {
                self.term.write_line(item)?;
            }
        }

        self.term.write_line("")?;
        Ok(())
    }
}

impl Default for UIComponents {
    fn default() -> Self {
        Self::new()
    }
}