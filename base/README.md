# Qiniu Sdk Base

七牛 dart 平台 sdk 的 base 包，为上层 sdk 提供基础设施和共享代码。

## 如何测试

创建 `.env` 文件，并输入如下内容

```
export QINIU_DART_SDK_ACCESS_KEY=
export QINIU_DART_SDK_SECRET_KEY=
export QINIU_DART_SDK_TOKEN_SCOPE=
```


在 `.env` 文件中填好敏感数据，即 ak、sk、scope

接着运行如下指令

`pub run test`
