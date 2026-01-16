## 0.7.5

* 文件进行第一次上传时，如果域名全部冻结，会随机选择一个域名进行上传

## 0.7.3

* 优化表单上传进度更新粒度
* 修复分片上传重试时进度超过`100%`的问题

## 0.7.2

* 移除 SystemInfo2 依赖，仅使用标准库 Platform 获取平台信息，修复 Android 平台的兼容性问题

## 0.7.1

* 修复由于 SystemInfo2 引入导致的 Web/iOS/Windows 平台的不兼容问题

## 0.7.0

* 增强区域查询和上传的可靠性

## 0.6.1

* 移除冗余的 dio 依赖声明

## 0.6.0

Breaking Changes
* Dart >= 3.0.0 & Flutter >= 3.16.0

## 0.5.0

* Upgrade dio to 5.0.0

Breaking Changes
* Dart >= 2.15 & Flutter >= 2.8.0
* Deprecated `PutByPartOptions`
* Deprecated `PutBySingleOptions`

## 0.4.0

* 增加 putBytes 支持 WEB 平台(#50)

## 0.3.0

* 增加 null-safety(#44)

## [0.2.0]

* 优化了 `StorageError` 输出的调用栈
* `CacheProvider` 的方法都改成异步的

## [0.1.0]

* Initial Release.
