你正在执行 CBS Category A 的 A-IMP-03：客户账户生命周期与客户入驻（Account Lifecycle and Client Onboarding）。

本轮仅执行 Phase 1 分析。禁止修改 metadata 源文件、禁止任何 Salesforce DML、禁止部署或激活、禁止生产操作与 UAT。

请按以下优先级读取：
1. 本文件包中的 A-IMP-03 中文受控执行提示词 v1.0；
2. Category A Solution Design v1.4；
3. A-IMP-01 v1.1 Corrected；
4. A-IMP-02 v1.1 Impact Report 与 Exact Manifest；
5. 当前 metadata 与只读运行时证据。

先确认：文件版本、ZIP SHA-256、API 67.0、Git branch/commit、A-IMP-02 状态和重叠组件。

完成：metadata 全量扫描、API / 路径校验、R01–R12 只读证据、现有 Account 基线决策表、Pre-change Impact Report、Exact Manifest、候选文件清单、T01–T24 测试计划、部署与回滚草案、冲突决策表。

不得创建自定义 Onboarding 对象、Account Record Type、LWC、Apex 服务、Checklist Custom Metadata 或 Manifest 外组件；不得提前实施 A-IMP-04 至 A-IMP-11；不得自动修改 Account、Task、Opportunity、Contract、User 或任何业务数据。

最终一行必须精确输出：
AWAITING A-IMP-03 MANIFEST APPROVAL
