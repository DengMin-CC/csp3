# GNSS+LEO 联合精密轨道钟差产品生成项目

## 项目概述
- 融合 LEO 星座 SP3 星历 + WUM GNSS SP3/CLK 产品，生成 GNSS+LEO 联合轨道钟差产品
- 上游项目：`F:\LeoSingle\oi`（LEO 星座仿真，产出 `sp3_YYYYDDD.sp3`）
- 核心工具：MATLAB 脚本 `mergeSP3.m`（已替代废弃的 csp3.exe）

## 语言与风格
- 始终使用简体中文回复
- 代码注释用英文，解释说明用中文
- 修改代码时先说思路，再给代码
- 常规文件修改不需要征求用户意见，直接改即可

## 输入数据

### LEO SP3（来自上游 oi 项目）
- 路径：`F:\LeoSingle\oi\sp3_YYYYDDD.sp3`
- 150 颗 LEO 卫星，PRN 201-350
- 坐标参考框架：ITRF（PANDA 积分输出）
- 时间系统：GPST
- SP3 epoch 起始于仿真日前一天 23:55（如 DOY 348 → MJD 60291.9965）
- 采样间隔：60 秒
- SP3 头部标识：`#aP`，由 PANDA 软件生成
- 新格式文件名：`sp3_YYYYDDD.sp3`（带 .sp3 后缀）

### LEO 星座构型
- PRN 201-320：12 轨道面 x 10 颗/面 = 120 颗，高度 975 km，倾角 55 度
- PRN 321-350：3 轨道面 x 10 颗/面 = 30 颗，高度 1100 km，倾角 87.4 度（极轨道）
- PRN 分配规则：200 + (plane-1)*10 + slot，第二组接着编号

### WUM GNSS 产品
- FTP：`ftp://igs.gnsswhu.cn`
- **FIN（最终产品）路径**：`/pub/gps/products/{GPS周}/WUM0MGXFIN_{DDD}0000_01D_05M_ORB.SP3.gz`
- **RAP（快速产品）路径**：
  - ORB：`/pub/whu/phasebias/{年}/orbit/WUM0MGXRAP_{DDD}0000_01D_05M_ORB.SP3.gz`
  - CLK：`/pub/whu/phasebias/{年}/clock/WUM0MGXRAP_{DDD}0000_01D_30S_CLK.CLK.gz`
- 注意：`/pub/gps/products/` 的 RAP ORB 有时会缺失，`/pub/whu/phasebias/` 更完整
- GPS 周计算：`week = floor((MJD - 44244) / 7)`
- SP3 采样间隔：5 分钟（轨道），坐标系 IGS20
- CLK 采样间隔：30 秒（钟差），RINEX 3.0 格式，钟差单位为秒
- 当前版本包含全部 GNSS 系统：GPS + GLONASS + Galileo + BDS + QZSS，共约 117 颗

## 时间约定
- 所有时间系统为 GPST
- 闰秒 GPS-UTC = 18，TAI-GPS = 19，TAI-UTC = 37
- MJD 与儒略日关系：MJD = JD - 2400000.5

---

## 目录结构与文件说明

```
F:\LeoSingle\csp3\
|
+-- mergeSP3.m              [核心] GNSS+LEO 联合 SP3 生成，含轨道插值 + 钟差仿真
|   - readSP3()           读取 SP3 文件（GNSS 或 LEO）
|   - readCLK()           读取 RINEX 3.0 CLK 文件
|   - lagrange_interp()     9 阶 Lagrange 轨道插值（标准 IGS 方法）
|   - writeSP3()          写出标准 SP3 格式
|
+-- run_batch.m             [批处理] DOY 166-169 批量生成联合 SP3
|
+-- === 基线 DOY 348（2023-12-14, GPS 周 2292, WUM FIN）===
+-- WUM0MGXFIN_20233480000_01D_05M_ORB.SP3   [WUM FIN 轨道] 5min, IGS20
+-- WUM0MGXFIN_20233480000_01D_30S_CLK.CLK   [WUM FIN 钟差] 30s
+-- sp3_2023348.sp3           [LEO SP3] 60s, 150 颗, 来自 oi 项目
+-- whu22924_new.sp3         [输出] 联合 SP3（GNSS+LEO, 30s, 含 LEO 仿真钟差）
|
+-- === DOY 166-169（2025-06-15~18, GPS 周 2371, WUM RAP）===
+-- WUM0MGXRAP_2025166x_01D_05M_ORB.SP3     [WUM RAP 轨道] x4
+-- WUM0MGXRAP_2025166x_01D_30S_CLK.CLK     [WUM RAP 钟差] x4
+-- sp3_2025166.sp3 ~ sp3_2025169.sp3       [LEO SP3] 60s, 150 颗 x4
+-- whu23710_new.sp3 ~ whu23713_new.sp3     [输出] ✅ 已生成
```

### 文件命名规则
| 文件模式 | 含义 | 示例 |
|---------|------|------|
| `whu{周}{wd}_new.sp3` | mergeSP3.m 生成的联合 SP3（30s） | whu22924_new.sp3, whu23710_new.sp3 |
| `sp3_YYYYDDD.sp3` | 纯 LEO SP3（60s，来自 oi 项目） | sp3_2025166.sp3 |
| `WUM0MGXFIN_{DDD}0000_01D_05M_ORB.SP3` | WUM 最终轨道产品（5min） | — |
| `WUM0MGXRAP_{DDD}0000_01D_05M_ORB.SP3` | WUM 快速轨道产品（5min） | — |
| `WUM0MGX{FIN\|RAP}_{DDD}0000_01D_30S_CLK.CLK` | WUM 钟差产品（30s） | — |

> 输出文件名 `whu{周}{wd}`：周 = GPS 周，wd = 周内序号（Sun=0, Mon=1, ... Sat=6）

---

## 工作流程

### 总体流程（理论设计）

```
上游 oi 项目               WUM 真实精密产品
  |                          |
  v                          v
LEO 轨道仿真              GNSS 精密轨道 (5min) + 精密钟差 (30s)
  |                          |
  +-- 内插 60s->30s           +-- 内插 5min->30s
  v                          +-- 随机分配给 GNSS -> 仿真钟差
LEO 轨道 (30s)               v
                             GNSS 仿真轨道+钟差 (30s)
  |                          |
  +-- 随机分配 GNSS 钟差      |
  v  -> LEO 仿真钟差          |
LEO 下行产品                |
  +----------+--------------+
             v
      合并 LEO 下行 + GNSS 仿真轨道钟差
             |
             v
      添加星历误差（另外实现）
             |
             v
      下行精密星历（最终产品）
```

### 步骤一：生成联合 SP3（mergeSP3.m）

```matlab
mergeSP3("WUM0MGXFIN_20233480000_01D_05M_ORB.SP3", ...
         "WUM0MGXFIN_20233480000_01D_30S_CLK.CLK", ...
         "sp3_2023348.sp3", ...
         "whu22924_new.sp3")
```

**输入：**
- WUM GNSS ORB SP3（5min 间隔，IGS20，120 颗 GNSS）
- WUM CLK（30s 间隔，RINEX 3.0，120 颗 GNSS，钟差单位秒）
- LEO SP3（60s 间隔，ITRF，150 颗 LEO）

**处理逻辑（10 步）：**
1. 读取 WUM GNSS ORB → 提取 120 颗 GNSS 卫星的位置（5min 间隔）
2. 读取 WUM CLK → 提取 120 颗 GNSS 卫星的钟差（30s 间隔，秒转微秒）
3. 读取 LEO SP3 → 提取 150 颗 LEO 卫星的位置（60s 间隔）
4. 检查 CLK 中缺失的 GNSS 卫星（如有则用 ORB 钟差作为回退）
5. 构建输出时间轴：30s 间隔，覆盖 LEO 完整范围（前一天 23:55 → 次日 00:05）
6. GNSS 轨道：9 阶 Lagrange 插值 5min→30s
7. LEO 轨道：9 阶 Lagrange 插值 60s→30s
8. GNSS 钟差：直接从 CLK 取值（30s 直接拷贝，边缘 epoch 线性外推）
9. **LEO 钟差：从 GNSS 卫星钟差中随机分配**——每颗 LEO 固定"认领"一颗 GNSS 卫星，全程使用其钟差值
   - `rng(42)` 固定随机种子，保证每次运行结果可复现
   - 每个 epoch 的同一 LEO 始终使用同一颗 GNSS 卫星的钟差（保持历元间一致性）
   - 边缘 epoch 用 `interp1` 线性外推
10. 写出标准 SP3 文件，270 颗卫星，2901 个 epoch

**输出：** `whu{周}{DOY}_new.sp3`

---

### 步骤二：融合 WUM 精确钟差（FusionORBCLK.m，已废弃的旧流程修补）

- 用途：csp3.exe 产出的联合 SP3 的 GNSS 钟差是错误的常量，此脚本用 WUM CLK 替换
- 已被 mergeSP3.m 替代，保留仅供参考

### 步骤三：更新 LEO 钟差（FUSION_GNSS_LEO.m，旧脚本，需更新）

- 用途：将已有联合 SP3 中的 LEO 钟差更新到新 LEO SP3
- 需要根据新的 PRN 编号方案调整匹配逻辑

---

## 当前配置状态

### 已处理的数据时段
| DOY | 日期 | GPS 周 | WUM 产品类型 | LEO SP3 | 联合 SP3 输出 | 状态 |
|-----|------|--------|-------------|---------|--------------|------|
| 348 | 2023-12-14 | 2292 | FIN | sp3_2023348.sp3 | whu22924_new.sp3 | ✅ 基线 |
| 166 | 2025-06-15 | 2371 | RAP | sp3_2025166.sp3 | whu23710_new.sp3 | ✅ |
| 167 | 2025-06-16 | 2371 | RAP | sp3_2025167.sp3 | whu23711_new.sp3 | ✅ |
| 168 | 2025-06-17 | 2371 | RAP | sp3_2025168.sp3 | whu23712_new.sp3 | ✅ |
| 169 | 2025-06-18 | 2371 | RAP | sp3_2025169.sp3 | whu23713_new.sp3 | ✅ |

### whu22924_new.sp3 产品验证结果（DOY 348 基线）
| 指标 | 旧版 (csp3.exe) | 新版 (mergeSP3.m) |
|------|-----------------|-------------------|
| 总卫星数 | 261 | **270** |
| GNSS 卫星 | 111 | **120** |
| LEO 卫星 | 150 | **150** |
| C41-C46 | 丢失 | **全部恢复 (2901 records)** |
| J02-J04 | 丢失 | **全部恢复 (2901 records)** |
| 时间覆盖 | 23:55→00:04:30 (截断) | **23:55→00:05 (完整)** |
| epoch 数 | 2900 | **2901** |
| GNSS 钟差 | 常量（错误） | **CLK 精确值（正确）** |
| LEO 钟差 | 全零 | **GNSS 随机分配（如 P201=4700.24 us）** |
| GNSS 轨道插值 | 9 阶 Lagrange | **9 阶 Lagrange（一致）** |
| 文件大小 | 47 MB | 51 MB |

### 联合 SP3 卫星构成
- DOY 348（2023, FIN）：GNSS ~120 颗 + LEO 150 颗 = ~270 颗
- DOY 166-169（2025, RAP）：GNSS ~117 颗 + LEO 150 颗 = ~267 颗
  - GNSS 构成随日期略有变化，具体以 SP3 头部 PRN 列表为准

### 数据规格
| 产品 | 采样间隔 | 坐标系 | 时间系统 |
|------|---------|--------|---------|
| LEO SP3 (sp3_YYYYDDD.sp3) | 60s | ITRF | GPST |
| WUM ORB | 5min | IGS20 | GPST |
| WUM CLK | 30s | — | GPST |
| 联合 SP3 (whu*_new.sp3) | 30s | WGS84 | GPST |

---

## csp3.exe 分析记录（已废弃，仅留档）

### 已验证的缺陷
1. **丢失 9 颗 GNSS 卫星**：C41-C46（BDS 6 颗）、J02-J04（QZSS 3 颗）
   - 根因：PRN 列表按固定行数解析，最后两行的卫星被截断
2. **GNSS 钟差为常量**：未使用 CLK 文件，全部卫星钟差不随时间变化
   - 例：G01 在 23:55、00:00、01:00 的钟差完全相同（6.294474 us），而 CLK 真实值为 163.94 us
3. **数据截断**：只覆盖约 24h（exit code 1 崩溃）
4. **轨道插值正确**：经验证使用 9 阶 Lagrange 插值（与标准 IGS 方法一致，00:00:30 处误差 0 米）

### 轨道插值方法验证
- 在 00:00:30 时刻，用 10 个 WUM ORB epoch（00:00~00:45）做 9 阶 Lagrange 插值
- 输出位置 = 13498.446512 km，与 csp3.exe 输出完全一致（差 0 米）
- 证明 csp3.exe 的轨道插值算法正确，问题仅在钟差和卫星缺失

---

## 注意事项和踩坑记录

### 钟差单位换算
- CLK 文件：秒（如 `0.163940917820E-03`）
- SP3 文件：微秒（如 `163.940918`）
- 换算：`CLK值 x 10^6 = SP3值`

### LEO 钟差随机分配规则
- 每颗 LEO 固定认领一颗 GNSS 卫星，全程使用其钟差
- 历元间保持一致：0s 用 C42 则 30s 也用 C42
- `rng(42)` 固定种子保证可复现
- 边缘 epoch 用线性外推

### 时间匹配机制
- 联合 SP3 起始于 23:55（LEO 时间轴起点），CLK 从 00:00 开始
- 23:55~00:00 的 5 分钟用线性外推
- 匹配通过秒数轴上的 `interp1` 自动处理

### MATLAB 版本兼容
- 老版 MATLAB 不支持 `datetime(1, N)` 预分配 → 用 `NaT(1, N)` 替代
- 老版 MATLAB 不支持 datetime `==` 比较 → 用字符串 key 去重
- 老版 MATLAB 的 `duration` 不能直接用于 `%d` → 用 `days()` 转数值
- 老版 MATLAB 的 `string` 类型不能用于 `fprintf` → 用 `char()` 转换
- 老版 MATLAB cell 数组 `horzcat` 要求行数相同 → 用 `vertcat` 拼接列向量

### 文件组织
- DOY 348 使用 WUM FIN 产品（基线），DOY 166-169 使用 WUM RAP 产品
- WUM RAP 数据源：`/pub/whu/phasebias/{年}/orbit/` 和 `/pub/whu/phasebias/{年}/clock/`

### WUM FTP 下载经验
- FTP 直连不需要代理：`curl -s -O "ftp://igs.gnsswhu.cn/..."`
- HTTPS/HTTP 通过代理（127.0.0.1:7890）经常 SSL 握手失败，不要用
- `/pub/gps/products/{GPS周}/` 的 RAP ORB 有时会缺失（如 DOY 169），`/pub/whu/phasebias/{年}/orbit/` 更完整
- 下载前先 `curl -s` 列目录 + grep 确认文件存在，避免 550 错误

---

## 会话记录

### 2026-04-21 会话：Git 版本控制 + DOY 166-169 批量处理

**本次完成的工作：**

1. **Git 版本控制初始化**
   - 配置用户：`LeoSingle / leosingle@local`
   - 代理：`http://127.0.0.1:7890`，SSL 后端：`openssl`（解决 schannel 断连）
   - 远程仓库：https://github.com/DengMin-CC/csp3
   - `.gitignore` 排除：`*.sp3 *.SP3 *.CLK *.gz *.exe *.bat .claude/ *.asv *.m~ *.mat`

2. **WUM 产品下载（DOY 166-169）**
   - DOY 166-168：先从 `/pub/gps/products/2371/` 下载了 FIN 产品，后改用 RAP 保持一致性
   - DOY 169：FIN 未发布，`/pub/gps/products/2371/` 的 RAP ORB 也缺失，最终在 `/pub/whu/phasebias/2025/orbit/` 找到
   - 经验：`/pub/whu/phasebias/` 的 RAP 产品比 `/pub/gps/products/` 更完整，应优先查这里
   - 来源路径：
     - ORB：`ftp://igs.gnsswhu.cn/pub/whu/phasebias/2025/orbit/WUM0MGXRAP_{DDD}0000_01D_05M_ORB.SP3.gz`
     - CLK：`ftp://igs.gnsswhu.cn/pub/whu/phasebias/2025/clock/WUM0MGXRAP_{DDD}0000_01D_30S_CLK.CLK.gz`

3. **项目目录清理**
   - 删除废弃文件：`csp3.exe`、`csp3.bat`、`FusionORBCLK.m`、`FUSION_GNSS_LEO.m`、`start-claude-glm.cmd`
   - 删除旧版输出：`whu22924.sp3`、`GLwhu22924.sp3`、`whu22925.sp3`、`whu22926.sp3`
   - 删除冗余数据：DOY 349/350 WUM 产品、旧格式 LEO SP3、`1/`、`orb/`
   - 保留：DOY 348 基线（WUM FIN）、DOY 166-169 数据（WUM RAP）

4. **DOY 166-169 批量生成**
   - 新增 `run_batch.m`：自动处理 DOY 166-169 四天
   - 输出文件命名：`whu{GPS周}{周内序号}_new.sp3`（Sun=0, Mon=1, ...）
   - MATLAB 后台运行成功，全部四天生成完毕

5. **新建 gnssdata 项目**
   - 目录：`F:\LeoSingle\gnssdata`
   - 仓库：https://github.com/DengMin-CC/gnssdata
   - 用途：统一管理 GNSS 精密产品下载与归档
   - CLAUDE.md 包含：数据源路径、下载方法、网络配置、文件命名规则、目录结构建议

**DOY 166-169 处理结果：**

| 文件 | DOY | 日期 | GNSS | LEO | Epochs | 大小 |
|------|-----|------|------|-----|--------|------|
| whu23710_new.sp3 | 166 | 2025-06-15 (Sun) | 111 | 150 | 2901 | 48 MB |
| whu23711_new.sp3 | 167 | 2025-06-16 (Mon) | 111 | 150 | 2901 | 48 MB |
| whu23712_new.sp3 | 168 | 2025-06-17 (Tue) | 111 | 150 | 2901 | 48 MB |
| whu23713_new.sp3 | 169 | 2025-06-18 (Wed) | 111 | 150 | 2901 | 48 MB |

**Git 提交记录：**
```
7cf173b init: GNSS+LEO 联合精密轨道钟差产品生成项目
933cf5c refactor: 清理项目目录，准备 DOY 166-169 批处理
```

**相关仓库：**
- csp3：https://github.com/DengMin-CC/csp3
- gnssdata：https://github.com/DengMin-CC/gnssdata
