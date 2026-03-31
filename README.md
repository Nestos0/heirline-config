# heirline-config

个人 heirline 配置，封装为独立 Neovim 插件。

## 目录结构

```
heirline-config/
├── lua/heirline-config/
│   ├── init.lua        -- 插件入口，暴露 M.setup()
│   ├── setup.lua       -- 调用 heirline.setup()，组装 statusline + tabline
│   ├── colors.lua      -- 颜色表、mode_colors、条件函数
│   ├── utils.lua       -- get_buf_names / is_repeated 工具函数
│   ├── statusline.lua  -- 所有状态栏组件 + StatusLine 定义
│   └── tabline.lua     -- 所有 tabline 组件 + TabLine 定义（含 TabPages）
└── plugins/
    └── heirline-config.lua  -- lazy.nvim 插件规格示例
```

## 安装

### 方法一：本地插件（推荐）

将 `lua/heirline-config/` 目录复制到你的 Neovim 配置中：

```sh
cp -r lua/heirline-config ~/.config/nvim/lua/
```

然后将 `plugins/heirline-config.lua` 放入你的 lazy.nvim 插件目录：

```sh
cp plugins/heirline-config.lua ~/.config/nvim/lua/plugins/
```

### 方法二：发布到 GitHub 后用 lazy.nvim 拉取

```lua
{
  "your-github-name/heirline-config.nvim",
  event = "UiEnter",
  dependencies = {
    "rebelot/heirline.nvim",
    "nvim-tree/nvim-web-devicons",
    "lewis6991/gitsigns.nvim",
  },
  config = function()
    require("heirline-config").setup()
  end,
}
```

## TabPages 功能

- **仅在 tab 页数量 ≥ 2 时**才渲染，位于 tabline 最右侧
- 显示每个 tab 的编号和当前 buffer 文件名（超过 12 字符自动截断）
- 点击 tab 名称：跳转到对应 tab
- 点击 `✕`：关闭该 tab（仍有多个 tab 时才显示）
- 点击 `+`：新建 tab

## 依赖

| 插件 | 用途 |
|---|---|
| `rebelot/heirline.nvim` | 核心框架 |
| `nvim-tree/nvim-web-devicons` | 文件图标 |
| `lewis6991/gitsigns.nvim` | Git 状态信息 |
