// 工具函数模块

/// 解析 cf_command 获取指定参数(-f或-o)指定的文件路径
pub fn parse_cf_command_for_file(cf_command: &str, param: &str) -> Option<String> {
    let mut parts = cf_command.split_whitespace();
    while let Some(part) = parts.next() {
        if part == param {
            return parts.next().map(ToString::to_string);
        }
    }
    None
}

/// 解析 cf_command 获取 -o 参数指定的文件路径
pub fn parse_cf_command_for_output_file(cf_command: &str) -> Option<String> {
    parse_cf_command_for_file(cf_command, "-o")
}

/// 获取result.csv文件路径，优先使用-o参数指定的文件
pub fn get_result_csv_path(cf_command: &str) -> String {
    parse_cf_command_for_output_file(cf_command).unwrap_or_else(|| "result.csv".to_string())
}

/// 创建域名和IP的映射关系，格式为 [[域名, IP], [域名, IP], ...]
/// 如果域名为空（未指定），则域名处设为极狐空字符串
pub fn create_domain_ip_mapping(
    ips: &[String],
    domains: &[String],
    add_ddns: &str,
) -> Vec<(String, String)> {
    ips.iter()
        .enumerate()
        .map(|(i, ip)| {
            if add_ddns == "未指定" || domains.is_empty() {
                (String::new(), ip.to_string())
            } else {
                let domain_index = i % domains.len();
                (domains[domain_index].to_string(), ip.to_string())
            }
        })
        .collect()
}