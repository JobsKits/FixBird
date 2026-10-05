# <font id=前言>[**HarmonyOS**](https://developer.huawei.com/consumer/cn/) 7 端</font>

![Jobs出品，必属精品](https://picsum.photos/1500/400)

[toc]

---

已为鸿蒙 7 保留独立端目录。按哥的阶段要求，等 [**iOS**](https://developer.apple.com/ios/) 用户端 / 师傅端评审确认后再实现，不在首期与 [**iOS**](https://developer.apple.com/ios/) 同时铺开。

后续按 [**iOS**](https://developer.apple.com/ios/) 确认的订单状态和 [**Go**](https://go.dev/) API 合同实现用户下单、师傅接单、报价确认、订单查询及主题 / 多语言能力；工具链版本、签名和分发方式以届时采用的 [**HarmonyOS**](https://developer.huawei.com/consumer/cn/) 7 官方开发文档为准。

鸿蒙端实现时沿用统一前端数据合同：首屏可先显示本地样例，页面仍照常请求 API；请求成功后以服务端数据替换，失败 / 超时继续用本地假数据；服务恢复后成功请求自动使用真数据。列表必须有无数据占位，[**iconfont**](https://www.iconfont.cn/) 网络图片必须配置本地 Logo 兜底。

<a id="🔚" href="#前言" style="font-size:17px; color:green; font-weight:bold;">我是有底线的➤点我回到首页</a>
