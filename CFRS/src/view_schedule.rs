use anyhow::Result;
use console::Term;
use std::path::PathBuf;
use crate::{Config, Resolve};

pub struct ViewSchedule {
    config: Config,
    term: Term,
}

impl ViewSchedule {
    pub fn new(config_path: PathBuf) -> Result<Self> {
        Ok(ViewSchedule {
            config: Config::load(&config_path)?,
            term: Term::stdout(),
        })
    }

    pub fn run(&mut self) -> Result<()> {
        loop {
            self.term.clear_screen()?;
            self.term.write_line("查看计划任务")?;

            let resolves = self.get_resolves()?;
            if resolves.is_empty() {
                self.term.write_line("未找到任何解析配置")?;
                self.term.read_key()?;
                break;
            }

            self.term.write_line("现有解析组:")?;
            let resolves_str = resolves.iter().map(|resolve| {
                format!("{} ({}, {})", resolve.ddns_name, resolve.hostname1, resolve.hostname2)
            }).collect::<Vec<_>>().join("\n");
            self.term.write_line(&resolves_str)?;
            self.term.write_line("")?;

            self.show_cron_example(&resolves[0])?;
        }
        Ok(())
    }

    fn show_cron_example(&self, resolve: &Resolve) -> Result<()> {
        let cf_path = std::env::current_exe()?;
        let ddns_name = &resolve.ddns_name;

        self.term.clear_screen()?;
        self.term.write_line("每4小时执行一次:")?;
        self.term.write_line(&format!("   0 */4 * * * {} {}", cf_path.display(), ddns_name))?;
        self.term.write_line("")?;
        self.term.write_line("每天5点执行一次:")?;
        self.term.write_line(&format!("   0 5 * * * {} {}", cf_path.display(), ddns_name))?;
        self.term.write_line("")?;
        self.term.write_line("计划任务格式: 分 时 日 月 周")?;

        self.term.read_key()?;
        Ok(())
    }

    fn get_resolves(&self) -> Result<Vec<Resolve>> {
        Ok(self.config.resolve.clone().unwrap_or_default())
    }
}