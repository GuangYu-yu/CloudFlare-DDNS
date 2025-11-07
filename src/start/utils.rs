// 工具函数模块

/// 解析 cf_command 获取指定参数(-f或-o)指定的文件路径
pub fn parse_cf_command_for_file(cf_command: &str, param: &str) -> Option<String> {
        cf_command
            .split_whitespace()
            .collect::<Vec<&str>>()
            .windows(2)
            .find(|window| window[0] == param)
            .and_then(|window| window.get(1))
            .map(|&s| s.to_string())
}

/// 解析 cf_command 获取 -o 参数指定的文件路径
pub fn parse_cf_command_for_output_file(cf_command: &str) -> Option<String> {
        parse_cf_command_for_file(cf_command, "-o")
}

/// 获取result.csv文件路径，优先使用-o参数指定的文件
pub fn get_result_csv_path(cf_command: &str) -> String {
        parse_cf_command_for_output_file(cf_command)
            .unwrap_or_else(|| "result.csv".to_string())
}

/// 创建域名和IP的映射关系，格式为 [[域名, IP], [域名, IP], ...]
/// 如果域名为空（未指定），则域名处设为极狐空字符串
pub fn create_domain_ip_mapping(
    ips: &[String],
    domains: &[String],
    add_ddns: &str,
) -> Vec<(String, String)> {
    let mut mapping = Vec::new();

    if add_ddns == "未指定" || domains.is_empty() {
        // 未指定域名时，所有IP都映射到空域名
        for ip in ips {
            mapping.push((String::new(), ip.to_string()));
        }
    } else {
        // 循环分配IP到域名
        let domain_count = domains.len();
        for (i, ip) in ips.iter().enumerate() {
            let domain_index = i % domain_count;
            let current_domain = domains[domain_index].to_string();
            mapping.push((current_domain, ip.to_string()));
        }
    }

    mapping
}