# <font id=前言>倒计时按钮</font>

![Jobs出品，必属精品](https://picsum.photos/1500/400)

[toc]

---

> 中文架构入口：[架构脉络与关键设计](#jobs-architecture)。

* 并非继承，而是利用分类对`UIButton`能力的补充

* 倒计时内核利用`JobsSwiftTimer`

* 状态持久化示例

  ```swift
  /// 是否正在倒计时这个状态除了本页使用以外，也要防止App闪退，所以需要实时记录在UserDefaults
  /// 倒计时剩余的时间，也需要用UserDefaults进行存取，防止App闪退
  /// 只有倒计时正在进行中的状态时，有剩余的时间（数据来源：UserDefaults存取，如果为0，则用默认值）
  private let countdownTimeKey = "com.BSports.countdownTimeKey"
  private let isCountdownTimeKey = "com.BSports.isCountdownTimeKey"
  
  private let defaultCountdownTime = 15 * 60
  /// 为真则正在跑计时器
  var isCountdownTime: Bool {
      get {
          UserDefaults.standard.bool(forKey: isCountdownTimeKey)
      }
      set {
          UserDefaults.standard.set(newValue, forKey: isCountdownTimeKey)
      }
  }
  
  var countdownTime: Int {
      get {
          // 不在倒计时，直接返回默认值
          guard isCountdownTime else {
              return defaultCountdownTime
          }
          let value = UserDefaults.standard.integer(forKey: countdownTimeKey)
          // 如果 UserDefaults 里是 0，说明异常或未存储，用默认值
          return value > 0 ? value : defaultCountdownTime
      }
      set {
          UserDefaults.standard.set(newValue, forKey: countdownTimeKey)
      }
  }
  ```

* 方案 1
  
  ```swift
  import JobsByUIKit
  import JobsSwiftBaseDefines
  
  private lazy var countdownButton: UIButton = {
      UIButton.sys()
          /// 普通@点按事件触发
          .onTap { [weak self] sender in
              guard let self else { return }
              self.点击事件()
          }
          .onCountdownTick { [weak self] btn, remain, total, kind in
              guard let self else { return }
              /// 正在倒计时
              isCountdownTime = YES
          }
          .onCountdownFinish { [unowned self] _, kind in
              print("✅ [\(kind.displayName)] 倒计时完成")
              isCountdownTime = NO
          }
          .byAddTo(self) { [unowned self] make in
  						/// TODO
          }
  }()
  ```
  
  ```swift
  import JobsSwiftBaseDefines

  /// 启动倒计时
  private func countDown () {
      guard isCountdownTime else {
          countdownButton.startTimer(
              total: 60,
              interval: 1,
              kind: nil) { [weak self] btn in
                  guard let self else { return }
                  isCountdownTime = YES
  								/// TODO
              };return
      }
  }
  ```
  
* 方案 2
  
  ```swift
  import JobsCountdownButton
  import JobsByUIKit
  import JobsSwiftBaseDefines
  
  private lazy var countdownButton: UIButton = {
      UIButton.sys()
          /// 倒计时按钮核心配置
          .byCountdown { cfg in
              cfg.mode = .down(from: 12)
              cfg.clickableWhileRunning = true
              cfg.onTapWhileRunning = { btn, _ in
                  "运行中被点击！".toast
              }
              cfg.renderConfiguration = { sec, base in
                  var c = base
                  c.title = "可点 \(sec)s"
                  return c
              }
          }
          /// 把「点击按钮」和「启动倒计时」自动绑定起来
          //.byCountdownOnTapAuto()
          .onTap { [weak self] sender in
              guard let self = self,
                    let ctrl = sender.jobsCountdownController
              else { return }
  
              if ctrl.isRunning {
                  // 正在跑
                  if ctrl.config.clickableWhileRunning {
                      ctrl.config.onTapWhileRunning?(sender, ctrl.config)
                  } else {
                      // 不可点就直接吞掉点击
                  }
              } else {
                  // 未运行 -> 开始
                  ctrl.start()
              }
          }
      
          .byAddTo(self) { [unowned self] make in
              /// TODO
          }
          .byBorderColor(JobsCor.cyan)
          .byBorderWidth(0.5)
          .byMasksToBounds(YES)
          .byClipsToBounds(YES)
          /// 切角@平面四个角全切
          .byCornerRadius(8.h)
          /// 切角@切固定角，iOS11及其以后可用。需要再配合layer.cornerRadius以生效
          .byMaskedCorners([.layerMinXMinYCorner, .layerMaxXMinYCorner])
          /// 切角@切固定角，兼容旧版本iOS系统
          .byCornerRaduis(corner: [.bottomLeft, .bottomRight], raduis: 4)
  }()
  ```

## 一、Jobs DSL 调用约定 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

Pod 内 Jobs 自维护代码统一采用“一镜到底”：同一配置语义的主对象只作为链起点出现一次；子对象通过宿主级 `byXxx` 或配置闭包继续收口。缺少链式入口时，先在低层补齐返回 `Self` 的 DSL，再改调用端。

<a id="jobs-architecture"></a>

## 二、架构脉络与关键设计 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

本节用于用中文快速理解组件，并为按框架重建提供入口；关注职责、运行关系和关键边界，不要求逐行复刻。

### 2.1、设计目的与职责划分 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

为 `UIButton` 挂接独立倒计时控制器，Config 描述增减方向、时间间隔、渲染方式和回调，Binder 提供便捷绑定，底层由 JobsSwiftTimer 驱动。

### 2.2、运行脉络 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

记录按钮原状态 → 按配置启动计时 → 渲染当前秒数 → 完成或停止 → 恢复按钮状态并通知

### 2.3、关键设计与边界 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

- 支持倒数和正向计数，回调中的秒数含义要随模式解释。
- [**iOS**](https://developer.apple.com/ios/) 15 的 `UIButton.Configuration` 与旧系统标题、图片等状态采用不同渲染路径，恢复状态也需分别保存。
- 计时中能否点击、是否立即渲染初始值、是否重置 UI 都是独立策略。
- 按钮不负责验证码请求，也不保证后台精确流逝；业务有效期应有独立的时间依据。

### 2.4、阅读与重建顺序 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

先读 Config，再看 Ctrl 的快照、tick 与结束路径，最后看 UIButton 扩展和 Binder 的持有关系。

源码定位（路径以本 README 所在目录为基准；只带走 README 时，可把文件名作为职责定位线索）：

- [JobsCountdownBtnConfig.swift](<./JobsCountdownBtnConfig.swift>)
- [JobsCountdownBinder.swift](<./JobsCountdownBinder.swift>)
- [JobsCountdownBtnCtrl.swift](<./JobsCountdownBtnCtrl.swift>)
- [UIButton+倒计时.swift](<./UIButton+倒计时.swift>)

依赖与编译入口：[JobsCountdownButton.podspec](<./JobsCountdownButton.podspec>)。其中显式依赖声明包括 `JobsByUIKit`、`JobsSwiftTimer`、`JobsSwiftBaseDefines`、`JobsSwiftDSL`。源码范围、资源及可选 subspec 以这里的声明为准；辅助脚本动态补充的依赖不在上述摘录中展开。

<a id="🔚" href="#前言" style="font-size:17px; color:green; font-weight:bold;">我是有底线的➤点我回到首页</a>
