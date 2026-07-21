# A-IMP-03 R01–R12 只读查询计划（中文执行版）v1.0

**控制原则：** 本文件只允许收集只读证据。禁止 DML、禁止写入型 anonymous Apex、禁止运行会更新记录的 Flow、禁止部署和激活。每一项必须记录 Org ID、执行用户、时间、查询文本、行数与受保护的输出路径。评审副本必须遮蔽客户及个人信息。

## R01 — Account 生命周期画像
```soql
SELECT Client_Status__c, COUNT(Id)
FROM Account
GROUP BY Client_Status__c
```
```soql
SELECT Id, Name, Client_Code__c, Client_Status__c, Notification_Email__c, OwnerId, Type
FROM Account
WHERE Client_Code__c = NULL OR Notification_Email__c = NULL OR OwnerId = NULL
ORDER BY Name
```
在实施 global validation 前，确认 org 内是否存在非 CBS Account population。

## R02 — 重复 Client Code
```soql
SELECT Client_Code__c, COUNT(Id)
FROM Account
WHERE Client_Code__c != NULL
GROUP BY Client_Code__c
HAVING COUNT(Id) > 1
```
另在导出文件中检查 trim 后与大小写归一化后的重复。不得更新 Client Code。

## R03 — 现有 Account 基线
使用支持的 relationship query 或分开执行的只读 query，收集 Account 关联 Opportunity、Contract、Task、Contact 与 active external User 计数。每个 Account 必须形成一行 baseline decision register。

## R04 — Opportunity 前置条件
```soql
SELECT AccountId, StageName, COUNT(Id)
FROM Opportunity
WHERE AccountId != NULL
GROUP BY AccountId, StageName
```
识别 Active / Inactive Account 中没有 Closed Won 证据的记录。不得修改 Opportunity stage。

## R05 — Contract readiness
```soql
SELECT Id, AccountId, ContractNumber, Status, StartDate, ContractTerm, EndDate, OwnerId
FROM Contract
ORDER BY AccountId, StartDate DESC
```
识别缺失日期、异常状态和存在多个候选 Contract 的 Account。

## R06 — Contract Files
先取得 R05 的 Contract IDs，然后分批查询：
```soql
SELECT Id, LinkedEntityId, ContentDocumentId, ShareType, Visibility
FROM ContentDocumentLink
WHERE LinkedEntityId IN ('<ContractId1>','<ContractId2>')
```
另通过 ContentDocument / ContentVersion 只读检查文件标题。不得把合同文件下载或复制到非受控位置。

## R07 — 现有 Task 使用情况
```soql
SELECT Type, Status, COUNT(Id)
FROM Task
GROUP BY Type, Status
```
```soql
SELECT Id, WhatId, WhoId, Subject, Type, Status, ActivityDate, OwnerId, CreatedDate
FROM Task
WHERE Subject LIKE '%onboard%' OR Subject LIKE '%client%'
ORDER BY CreatedDate DESC
```
评估 Client Onboarding Type 与 checklist subject 是否会和现有 Task 发生冲突。

## R08 — Active external Users
```soql
SELECT Id, Username, IsActive, UserType, Profile.Name, ContactId, Contact.AccountId
FROM User
WHERE ContactId != NULL AND IsActive = TRUE
ORDER BY Contact.AccountId
```
评审副本必须遮蔽 Username。

## R09 — Roles、Permissions 与审批候选人
```soql
SELECT Id, Name, DeveloperName, ParentRoleId FROM UserRole ORDER BY Name
```
```soql
SELECT AssigneeId, PermissionSet.Name, PermissionSet.IsOwnedByProfile
FROM PermissionSetAssignment
WHERE PermissionSet.Name LIKE 'CBS%'
ORDER BY AssigneeId, PermissionSet.Name
```
识别 active authorised administrator candidates，并验证 maker-checker separation。不得分配权限。

## R10 — Feature 与 Capacity Setup 检查
只读检查：
- Flow Approval Process availability 与限制；
- 当前 active Flow versions；
- Account field-history 已跟踪字段数量与容量；
- Task history capability；
- queue / approver configuration；
- email、custom notification 与 fault logging mechanism。

保存 Setup screenshot 或 metadata export，但不得启用任何 feature。

## R11 — Automation 与 Configuration Drift
只读检索或检查所有 active Account / Task automation、Apex trigger、workflow / process remnants、quick actions、page / app assignments，以及 ZIP 中未出现的 approval assets。记录 component name 与 version。

## R12 — 最新基线比较
在独立只读目录执行 fresh metadata retrieve，计算 SHA-256，并对比：
1. Credit Bureau Sandbox 20260715.zip；
2. 最新批准的 A-IMP-02 branch / as-built retrieve。

不得覆盖受控 baseline。

## 固定最终停止语句
`AWAITING A-IMP-03 MANIFEST APPROVAL`
