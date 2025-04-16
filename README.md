# GEOIP LIST工具

这是一个用于下载和处理国家IP地址列表的工具。它可以从各个区域互联网注册管理机构（RIR）下载IP地址分配数据，并支持多种输出格式。

## 功能特点

- 自动选择合适的数据源（APNIC、RIPE、ARIN、LACNIC、AFRINIC）
- 支持IPv4和IPv6地址
- 支持多种输出格式：
  - 简单的CIDR列表
  - ipset命令格式
  - nftables配置格式
- 自动处理IP地址段计算
- 支持输出到文件或标准输出

## 安装

1. 确保系统已安装 `curl` 和 `awk`
2. 下载脚本：
```bash
wget https://raw.githubusercontent.com/0x5826/GEOIP-LIST/geoip-list.sh
chmod +x geoip-list.sh
```

## 使用方法

### 基本用法

```bash
./geoip-list.sh -c <国家代码> -t <IP类型>
```

### 参数说明

| 参数 | 说明 | 示例 |
|------|------|------|
| -c, --country | 指定国家代码 | CN, US, BR |
| -t, --type | 指定IP类型（4或6） | 4, 6 |
| -o, --output | 指定输出文件 | output.txt |
| -f, --format | 指定输出格式 | list, ipset, nft |
| -h, --help | 显示帮助信息 | |

### 输出格式

1. **list**（默认）：简单的CIDR列表
   ```
   1.0.1.0/24
   1.0.2.0/23
   ...
   ```

2. **ipset**：ipset命令格式
   ```bash
   create CN_ipv4 hash:net family inet hashsize 1024 maxelem 65536
   add CN_ipv4 1.0.1.0/24
   add CN_ipv4 1.0.2.0/23
   ...
   ```

3. **nft**：nftables配置格式
   ```bash
   table ip geoip {
       set CN_ipv4 {
           type ipv4_addr
           flags interval
           1.0.1.0/24,
           1.0.2.0/23,
           ...
       }
   }
   ```

### 使用示例

1. 下载中国的IPv4地址列表：
```bash
./geoip-list.sh -c CN -t 4
```

2. 生成美国的IPv6地址ipset格式：
```bash
./geoip-list.sh -c US -t 6 -f ipset -o usa_ipv6.ipset
```

3. 生成巴西的IPv4地址nftables配置：
```bash
./geoip-list.sh -c BR -t 4 -f nft -o brazil_ipv4.nft
```

## 数据源

工具会自动根据国家代码选择合适的数据源：

- APNIC：亚太地区（中国、日本、韩国等）
- RIPE NCC：欧洲（德国、法国、英国等）
- ARIN：北美（美国、加拿大）
- LACNIC：拉丁美洲（巴西、墨西哥等）
- AFRINIC：非洲（南非、埃及等）

## 注意事项

1. 确保有足够的磁盘空间存储临时文件
2. 建议定期更新IP地址列表
3. 对于大型国家（如中国、美国），建议使用文件输出而不是标准输出

## 常见问题

1. **如何更新已生成的ipset？**
   ```bash
   ipset destroy CN_ipv4
   ./geoip-list.sh -c CN -t 4 -f ipset | ipset restore
   ```

2. **如何应用nftables配置？**
   ```bash
   nft -f brazil_ipv4.nft
   ```

## 许可证

MIT License

## 贡献

欢迎提交问题和改进建议！ 
