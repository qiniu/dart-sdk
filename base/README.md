# Qiniu Sdk Base

七牛 dart 平台 sdk 的 base 包，为上层 sdk 提供基础设施和共享代码。

## 如何测试

先在 `.env` 填好敏感数据，即 ak、sk、scope

> 如果你担心 `.env` 被提交上来，可以试试 `git update-index --assume-unchanged .env`

接着运行如下指令

`pub run test`
