<p align="center"><b>Pinza</b> · 把便签晾在屏幕顶上的一根绳子上<br><sub>Notes, hung out on a line above your screen.</sub></p>

Pinza 是 [Tendedero](https://github.com/alejandrobujan/tendedero) 的便签版：UI 与交互完全沿用原项目——
同一根细绳、同样的玻璃卡片和铝制夹子、同样的摆动与微风、同样的手势——只是挂在绳上的不再只是截图，而是 **任何东西的便签**：
写下的文字、图片、PDF、文档、视频、压缩包……任意文件类型都能挂上去。

每张便签就是一个文件，所以它在绳上的行为和截图一模一样：拖进 App 就发送，拖进文件夹就留下文件，拖到废纸篓就放手。
写下的、复制的、拖进来的内容存放在 `~/Library/Application Support/Pinza/Notes/`；从访达拖来或复制的文件留在原处，绳上只是挂着它。

## 挂上什么，怎么挂

| 来源 | 绳上的样子 |
|:--|:--|
| <kbd>⌃⌥N</kbd> 写一张便签 | 一张写着字的纸（`.txt`），从纸面飞上绳子 |
| 把任何文件从访达拖到绳上 | 文件的预览（图片、PDF、文稿、视频等由“快速查看”生成）；预览不了的，卡片上用大字写出文件类型，如 `.md`、`.pptx`、`.docx`，并附图标和文件名 |
| 从其他 App 拖来图片或文字 | 图片存成 `.png`，文字存成便签 |
| 复制（打开“挂上复制的内容”后） | 复制的文字、图片、文件都会挂上 |
| 监视的文件夹（如“下载”） | 新出现的任何文件都会挂上 |

拖着东西碰到菜单栏，绳子就会降下来接住它，空绳子也一样。

## 看不见，却够得着

把指针停在菜单栏，绳子就会滑下来；移开，它就收回去。
按 <kbd>⌃</kbd>&thinsp;<kbd>⌥</kbd>&thinsp;<kbd>N</kbd> 写一张便签，按 <kbd>⌘</kbd>&thinsp;<kbd>↩</kbd>，它会从纸面飞上绳子挂好。

## 一个手势一件事

| 手势 | 作用 |
|:--|:--|
| 单击 | 复制：文字便签复制文字，图片复制图片，其他复制文件本身 |
| 按住 | 文字便签在纸上编辑，图片用“标记”编辑，其他文件快速查看 |
| 双击 | 用对应的 App 打开（在别处改了，绳上的预览也会跟着更新） |
| 用力点按 | 快速查看 |
| 拖进 App | 发送文字或文件，便签留在绳上 |
| 拖进文件夹 | 留下文件，便签离开绳子 |
| 拖到废纸篓，或点左上角的叉 | 放手 |
| 指针停在菜单栏 | 在这块屏幕上放下绳子 |
| 点击菜单栏任何东西 | 收起绳子 |
| 双指横扫 / 滚轮 | 在很长的绳子上前后移动 |
| <kbd>⌃</kbd>&thinsp;<kbd>⌥</kbd>&thinsp;<kbd>T</kbd> | 显示或隐藏绳子 |
| <kbd>⌃</kbd>&thinsp;<kbd>⌥</kbd>&thinsp;<kbd>N</kbd> | 写一张新便签 |

便签纸上：<kbd>⌘</kbd>&thinsp;<kbd>↩</kbd> 挂上（或保存），<kbd>Esc</kbd> 收起——没写完的新便签会留作草稿，下次接着写。

**便签纸能放任何东西。** 截完图直接 <kbd>⌘</kbd>&thinsp;<kbd>V</kbd> 贴进去，或者把任何文件（PDF、文稿、压缩包……）粘贴或拖到纸上，
它们会和文字一起存进这张便签（存成 `.rtfd` 富文本，文件就装在里面）；只有文字的便签仍然是 `.txt`。
绳上的卡片会把第一张图片显示在文字上方；只放了文件的便签，卡片显示第一个文件：文本类文件直接显示内容，其他文件显示预览或文件类型。从网页或文档复制的文字会按便签自己的字体贴入。

**刚复制的内容会主动问你。** 按 <kbd>⌃⌥N</kbd> 时，如果剪贴板里有最近 10 分钟内复制的文字、截图或文件，
纸的上方会出现“使用刚才复制的内容？”，点“使用”就放进便签，点 ✕ 就不再为这次复制提问。密码管理器标记为私密的内容不会出现。
两个快捷键都可以在菜单栏的“快捷键”里修改。

右键便签：复制、编辑、打开、快速查看、在访达中显示、存储到桌面、丢弃、取下左侧/右侧全部。

## 从截图到便签：对照

| Tendedero（截图） | Pinza（便签） |
|:--|:--|
| 截一张图，它就挂上去 | <kbd>⌃⌥N</kbd> 写一张便签，或把任何文件拖到绳上 |
| 截图从截取的位置飞上绳子 | 便签从纸面飞上绳子 |
| 挂上复制的图片 | 挂上复制的文字、图片和文件（可选，图钉图标会变实心） |
| 接管截图、不再堆在桌面 | 便签都放在 Pinza 自己的文件夹里，只留下你拖出去的 |
| 同时监视文件夹（新图片） | 同时监视文件夹（任何新文件） |
| 按住用“标记”编辑 | 文字在纸上编辑，图片用“标记”编辑 |
| 屏幕录制：按住修剪 | — |
| 绳上保留 25 / 50 / 100 张、大小、全屏 App 上、声音、登录时打开 | 全部保留 |

密码管理器标记为私密的内容、带文件的复制、以及从绳上复制出来的便签，都不会被当作新便签挂上。

## 隐私

没有账号，不联网，不统计。便签只存在你的 Mac 上。

## 构建

需要 macOS 14 及以上和 Swift 工具链（Xcode 可选）：

```sh
git clone https://github.com/mdongsheng/tendedero_notes.git
cd tendedero_notes
scripts/build-app.sh
open build/Pinza.app
```

每次推送，GitHub Actions 都会在 macOS 上构建，并把 `Pinza.zip` 作为构建产物上传。
本地构建是临时签名（ad hoc）的。

<details>
<summary>代码结构</summary>
<br>

| 文件 | 作用 |
|:--|:--|
| `AppDelegate.swift` | 菜单栏、快捷键、绳子的放下与收起 |
| `LinePanel.swift` | 屏幕顶端那条透明的长条窗口 |
| `LineView.swift` | 绳子本身，以及每张便签挂在哪里 |
| `PeggedView.swift` | 一张便签：玻璃框、夹子、摆动和微风 |
| `NoteCard.swift` | 把便签文字画成绳上的那张纸 |
| `FileCard.swift` | 其他文件的预览：快速查看缩略图，或图标加文件名 |
| `Intake.swift` | 把复制或拖来的文件、图片、文字变成便签 |
| `DropView.swift` | 绳子接住拖过来的东西 |
| `Markup.swift` | 用系统“标记”编辑图片并存回 |
| `NoteEditor.swift` | 写便签、改便签的那张纸 |
| `GrabArea.swift` | 单击、按住、拖放 |
| `CaptureFlight.swift` | 便签飞上绳子、从绳上掉落的动画 |
| `NoteWatcher.swift` | 发现文件夹里的新文件和改动 |
| `ClipboardWatcher.swift` | 发现复制的内容 |
| `Notes.swift` | 便签文件：存放、命名、读写 |
| `FullScreen.swift` | 知道什么时候该藏起来 |
| `Line.swift` | 绳上挂着什么，以及能对它们做什么 |

翻译在 `Sources/Pinza/Resources`，每种语言一个 `.lproj` 文件夹（目前是英文和简体中文）。
`swift scripts/check-strings.swift` 会检查是否有遗漏。

</details>

---

<sub>
Pinza 基于 Alejandro Buján 的 <a href="https://github.com/alejandrobujan/tendedero">Tendedero</a>（MIT 许可）修改而来。
按照 Tendedero 的许可要求，本项目使用自己的名字和图标，并非 Tendedero，也未获得其作者背书。见 <a href="LICENSE">LICENSE</a>。
</sub>
