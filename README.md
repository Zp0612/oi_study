# OI 算法学习

我的算法与数据结构学习记录。

## 目录结构

```
├── templates/               # 算法模板（二分、图论、DP 等）
│   └── bucket_sort.cpp      #   桶排序
├── problems/                # 刷题记录
│   ├── leetcode/            #   力扣（easy / medium / hard）
│   ├── luogu/               #   洛谷
│   ├── poj/                 #   POJ / 百练
│   │   └── 1222-lights-out/ #   熄灯问题（位运算枚举）
│   └── other/               #   其他来源
├── notes/                   # 学习笔记
└── README.md
```

## 刷题记录

| # | 题目 | 来源 | 难度 | 算法 | 日期 |
|---|------|------|------|------|------|
| 1 | 1222 熄灯问题 | POJ | ★★ | 位运算枚举 | - |

## 算法模板

| 模板 | 文件 | 说明 |
|------|------|------|
| 桶排序 | `templates/bucket_sort.cpp` | 数据均匀分布时 O(n) |

## Commit 规范

```
solve: <来源> <题号> <题名>      # 做新题
improve: <题号> <改进点>         # 优化解法
add-solution: <题号> <方法>      # 补不同解法
template: <算法名>               # 添加/更新模板
note: <内容>                     # 学习笔记
```

**示例：**

```bash
git commit -m "solve: luogu P1001 A+B Problem"
git commit -m "solve: leetcode 0001 两数之和"
git commit -m "improve: leetcode 0001 优化为一遍哈希"
git commit -m "template: 快速排序"
```

## 日常流程

```bash
cd d:/lzp/oi_study
git add .
git commit -m "solve: <来源> <题号> <题名>"
git push
```

**每次只提交一道题**，保持历史干净可查。
