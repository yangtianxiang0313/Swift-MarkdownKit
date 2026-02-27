# TODO

> 有空时处理的事项

---

## 待办

### 依赖倒置修复

**后续修复**：梳理并修复所有当前依赖不倒置的代码，避免在新增 View / Fragment 等时，框架内部需要新增分支或 switch。

- 目标：用户扩展时零侵入，框架零 switch
- 参考：`.cursor/rules/design-principles.mdc` 中的「依赖倒置」原则
- 已按此原则设计：Fragment 高度计算（FragmentHeightProvider 注入）；待排查：createFragmentView、configureFragmentView、isViewTypeMatching、ReuseIdentifier 等是否仍有类型分支

---
