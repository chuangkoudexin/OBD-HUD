# 发布到 GitHub 开源仓库

本地仓库已经初始化并完成第一个提交，准备好开源发布。

## 方案 A: 用 GitHub CLI (推荐)

```bash
# 1. 在电脑上登录 GitHub (会打开浏览器, 不需要把 Token 告诉任何人)
gh auth login

# 2. 在项目目录创建公开仓库并推送
cd obd_hud
gh repo create obd-hud --public --source . --push
```

## 方案 B: 用 Git 命令

```bash
# 1. 在 GitHub 上先创建一个空仓库 (不要勾选 README / LICENSE / .gitignore)
#    例如 https://github.com/<你的用户名>/obd-hud

# 2. 添加远程地址并推送
cd obd_hud
git remote add origin https://github.com/<你的用户名>/obd-hud.git
git push -u origin master
```

> 推送时会要求输入 GitHub 账号密码或 Personal Access Token。
> 出于安全考虑，不要把你的 Token 发给我，请在你的电脑上完成登录/推送即可。

## 本地仓库状态

- 分支: `master`
- 首个提交: `f28df38 Initial open-source release: OBD HUD Flutter app`
- 已包含: 完整 Flutter 工程、CI、MIT License、README、真机截图
- 已忽略: `build/`、`dist/`、`*.apk`、日志、`.dart_tool/` 等
