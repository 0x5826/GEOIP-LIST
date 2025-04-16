#!/bin/bash

# 显示帮助信息
show_help() {
    echo "用法: $0 [选项]"
    echo "选项:"
    echo "  -c, --country CODE    指定国家代码（例如：CN, US, BR）"
    echo "  -t, --type TYPE       指定IP类型（4 或 6）"
    echo "  -o, --output FILE     指定输出文件（默认输出到标准输出）"
    echo "  -f, --format FORMAT   指定输出格式（可选：list, ipset, nft）"
    echo "  -h, --help            显示帮助信息"
    echo ""
    echo "示例:"
    echo "  $0 -c CN -t 4 -o china_ipv4.txt     下载中国的IPv4地址列表到文件"
    echo "  $0 -c US -t 6 -f ipset              生成美国的IPv6地址ipset格式"
    echo "  $0 -c BR -t 4 -f nft                生成巴西的IPv4地址nftable格式"
}

# 默认值
COUNTRY=""
IP_TYPE="4"
OUTPUT_FILE=""
SOURCE="auto"
FORMAT="list"

# 数据源URL
declare -A SOURCE_URLS=(
    ["apnic"]="https://ftp.apnic.net/stats/apnic/delegated-apnic-latest"
    ["ripe"]="https://ftp.ripe.net/ripe/stats/delegated-ripencc-latest"
    ["arin"]="https://ftp.arin.net/pub/stats/arin/delegated-arin-extended-latest"
    ["lacnic"]="https://ftp.lacnic.net/pub/stats/lacnic/delegated-lacnic-latest"
    ["afrinic"]="https://ftp.afrinic.net/pub/stats/afrinic/delegated-afrinic-latest"
)

# 国家代码到RIR的映射
declare -A COUNTRY_TO_RIR=(
    # APNIC (亚太地区)
    ["CN"]="apnic" ["JP"]="apnic" ["KR"]="apnic" ["AU"]="apnic" ["NZ"]="apnic"
    ["IN"]="apnic" ["ID"]="apnic" ["MY"]="apnic" ["PH"]="apnic" ["SG"]="apnic"
    ["TH"]="apnic" ["VN"]="apnic" ["TW"]="apnic" ["HK"]="apnic" ["MO"]="apnic"
    
    # RIPE NCC (欧洲)
    ["DE"]="ripe" ["FR"]="ripe" ["GB"]="ripe" ["IT"]="ripe" ["ES"]="ripe"
    ["NL"]="ripe" ["RU"]="ripe" ["SE"]="ripe" ["CH"]="ripe" ["UA"]="ripe"
    ["PL"]="ripe" ["BE"]="ripe" ["AT"]="ripe" ["DK"]="ripe" ["FI"]="ripe"
    
    # ARIN (北美)
    ["US"]="arin" ["CA"]="arin"
    
    # LACNIC (拉丁美洲)
    ["BR"]="lacnic" ["MX"]="lacnic" ["AR"]="lacnic" ["CL"]="lacnic" ["CO"]="lacnic"
    ["PE"]="lacnic" ["VE"]="lacnic" ["EC"]="lacnic" ["UY"]="lacnic" ["PY"]="lacnic"
    
    # AFRINIC (非洲)
    ["ZA"]="afrinic" ["EG"]="afrinic" ["NG"]="afrinic" ["KE"]="afrinic" ["TZ"]="afrinic"
    ["ET"]="afrinic" ["GH"]="afrinic" ["CI"]="afrinic" ["CM"]="afrinic" ["DZ"]="afrinic"
)

# 解析命令行参数
while [[ $# -gt 0 ]]; do
    case $1 in
        -c|--country)
            COUNTRY="$2"
            shift 2
            ;;
        -t|--type)
            IP_TYPE="$2"
            shift 2
            ;;
        -o|--output)
            OUTPUT_FILE="$2"
            shift 2
            ;;
        -f|--format)
            FORMAT="$2"
            shift 2
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            echo "错误: 未知选项 $1"
            show_help
            exit 1
            ;;
    esac
done

# 验证参数
if [ -z "$COUNTRY" ]; then
    echo "错误: 必须指定国家代码"
    show_help
    exit 1
fi

if [ "$IP_TYPE" != "4" ] && [ "$IP_TYPE" != "6" ]; then
    echo "错误: IP类型必须是 4 或 6"
    show_help
    exit 1
fi

if [ "$FORMAT" != "list" ] && [ "$FORMAT" != "ipset" ] && [ "$FORMAT" != "nft" ]; then
    echo "错误: 输出格式必须是 list, ipset 或 nft"
    show_help
    exit 1
fi

# 自动选择数据源
if [ "$SOURCE" = "auto" ]; then
    if [ -n "${COUNTRY_TO_RIR[$COUNTRY]}" ]; then
        SOURCE="${COUNTRY_TO_RIR[$COUNTRY]}"
        echo "自动选择数据源: $SOURCE"
    else
        echo "警告: 无法自动确定国家 $COUNTRY 的数据源，默认使用 APNIC"
        SOURCE="apnic"
    fi
fi

if [ -z "${SOURCE_URLS[$SOURCE]}" ]; then
    echo "错误: 不支持的数据源 '$SOURCE'"
    echo "支持的数据源: ${!SOURCE_URLS[*]}"
    exit 1
fi

# 检查curl是否可用
if ! command -v curl &> /dev/null; then
    echo "错误: 需要安装curl"
    exit 1
fi

# 下载并处理IP地址列表
echo "正在从${SOURCE}下载${COUNTRY}的IPv${IP_TYPE}地址列表..."

# 创建临时文件
TEMP_FILE=$(mktemp)

# 下载数据
if ! curl -fsSLk "${SOURCE_URLS[$SOURCE]}" -o "$TEMP_FILE"; then
    echo "错误: 下载数据失败"
    rm -f "$TEMP_FILE"
    exit 1
fi

# 处理数据
case "$FORMAT" in
    "list")
        if [ "$IP_TYPE" = "4" ]; then
            awk -F\| -v country="$COUNTRY" \
                '$2 == country && $3 == "ipv4" { 
                    printf("%s/%d\n", $4, 32-log($5)/log(2)) 
                }' "$TEMP_FILE" > "${OUTPUT_FILE:-/dev/stdout}"
        else
            awk -F\| -v country="$COUNTRY" \
                '$2 == country && $3 == "ipv6" { 
                    printf("%s/%d\n", $4, $5) 
                }' "$TEMP_FILE" > "${OUTPUT_FILE:-/dev/stdout}"
        fi
        ;;
    "ipset")
        if [ "$IP_TYPE" = "4" ]; then
            echo "create ${COUNTRY}_ipv4 hash:net family inet hashsize 1024 maxelem 65536" > "${OUTPUT_FILE:-/dev/stdout}"
            awk -F\| -v country="$COUNTRY" \
                '$2 == country && $3 == "ipv4" { 
                    printf("add %s_ipv4 %s/%d\n", country, $4, 32-log($5)/log(2)) 
                }' "$TEMP_FILE" >> "${OUTPUT_FILE:-/dev/stdout}"
        else
            echo "create ${COUNTRY}_ipv6 hash:net family inet6 hashsize 1024 maxelem 65536" > "${OUTPUT_FILE:-/dev/stdout}"
            awk -F\| -v country="$COUNTRY" \
                '$2 == country && $3 == "ipv6" { 
                    printf("add %s_ipv6 %s/%d\n", country, $4, $5) 
                }' "$TEMP_FILE" >> "${OUTPUT_FILE:-/dev/stdout}"
        fi
        ;;
    "nft")
        if [ "$IP_TYPE" = "4" ]; then
            echo "table ip geoip {" > "${OUTPUT_FILE:-/dev/stdout}"
            echo "    set ${COUNTRY}_ipv4 {" >> "${OUTPUT_FILE:-/dev/stdout}"
            echo "        type ipv4_addr" >> "${OUTPUT_FILE:-/dev/stdout}"
            echo "        flags interval" >> "${OUTPUT_FILE:-/dev/stdout}"
            awk -F\| -v country="$COUNTRY" \
                '$2 == country && $3 == "ipv4" { 
                    printf("        %s/%d,\n", $4, 32-log($5)/log(2)) 
                }' "$TEMP_FILE" >> "${OUTPUT_FILE:-/dev/stdout}"
            echo "    }" >> "${OUTPUT_FILE:-/dev/stdout}"
            echo "}" >> "${OUTPUT_FILE:-/dev/stdout}"
        else
            echo "table ip6 geoip {" > "${OUTPUT_FILE:-/dev/stdout}"
            echo "    set ${COUNTRY}_ipv6 {" >> "${OUTPUT_FILE:-/dev/stdout}"
            echo "        type ipv6_addr" >> "${OUTPUT_FILE:-/dev/stdout}"
            echo "        flags interval" >> "${OUTPUT_FILE:-/dev/stdout}"
            awk -F\| -v country="$COUNTRY" \
                '$2 == country && $3 == "ipv6" { 
                    printf("        %s/%d,\n", $4, $5) 
                }' "$TEMP_FILE" >> "${OUTPUT_FILE:-/dev/stdout}"
            echo "    }" >> "${OUTPUT_FILE:-/dev/stdout}"
            echo "}" >> "${OUTPUT_FILE:-/dev/stdout}"
        fi
        ;;
esac

# 清理临时文件
rm -f "$TEMP_FILE"

# 显示结果统计
if [ -n "$OUTPUT_FILE" ]; then
    COUNT=$(wc -l < "$OUTPUT_FILE")
    echo "完成！共找到 ${COUNT} 个IPv${IP_TYPE}地址段，已保存到 ${OUTPUT_FILE}"
else
    echo "完成！"
fi
