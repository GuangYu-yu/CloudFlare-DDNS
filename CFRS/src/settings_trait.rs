use anyhow::Result;
use std::path::PathBuf;
use crate::Config;

/// 通用Settings trait，统一处理配置的加载、保存和基本交互
pub trait Settings {
    /// 获取配置路径
    fn config_path(&self) -> &PathBuf;
    
    /// 获取配置的可变引用
    fn config_mut(&mut self) -> &mut Config;
    
    /// 加载配置
    fn load_config(&mut self) -> Result<()> {
        let config = Config::load(self.config_path())?;
        *self.config_mut() = config;
        Ok(())
    }
}

/// 宏：为结构体实现 Settings trait
#[macro_export]
macro_rules! impl_settings {
    ($struct_name:ident) => {
        impl Settings for $struct_name {
            fn config_path(&self) -> &PathBuf {
                &self.config_path
            }
            
            fn config_mut(&mut self) -> &mut Config {
                &mut self.config
            }
        }
    };
}
