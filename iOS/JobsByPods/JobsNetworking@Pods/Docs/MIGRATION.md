# <font id=前言>JobsNetworking vNext compatibility notes</font>

![Jobs出品，必属精品](https://picsum.photos/1500/400)

[toc]

---

- `DefaultJobsAgent` is kept as a public typealias to `JobsDefaultAgent`.
- `APIResponse<T>` is restored for legacy business-envelope decoding.
- `AnySendable` remains available as a deprecated typealias to `JobsValue`.
- `JobsBatch.concurrent` and `JobsBatch.chain` remain available and forward to `JobsWorkflow`.
- `JobsNetworking/AF5` and `JobsNetworking/AF4` are preserved as compatibility subspecs so old Podfiles do not break.
- New projects should prefer `Core + AF5 + Async` (and `PromiseKit` only when truly needed).

<a id="🔚" href="#前言" style="font-size:17px; color:green; font-weight:bold;">我是有底线的➤点我回到首页</a>
