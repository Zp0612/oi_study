#include <iostream>
#include <cstring>  // 用于数组拷贝
using namespace std;

// 5行6列固定大小
const int ROWS = 5;
const int COLS = 6;

// 方向数组：自身 + 上下左右
const int dirs[5][2] = {{0,0}, {-1,0}, {1,0}, {0,-1}, {0,1}};

// 按下 (i,j) 位置的按钮，翻转对应灯的状态
void press(int grid[ROWS][COLS], int i, int j) {
    for (int d = 0; d < 5; d++) {
        int ni = i + dirs[d][0];
        int nj = j + dirs[d][1];
        // 边界判断，仅翻转矩阵内的灯
        if (ni >= 0 && ni < ROWS && nj >=0 && nj < COLS) {
            grid[ni][nj] ^= 1;  // 异或1，0变1，1变0
        }
    }
}

int main() {
    int lights[ROWS][COLS];   // 存储初始灯的状态
    int grid[ROWS][COLS];     // 临时存储操作中的灯状态
    int buttons[ROWS][COLS];  // 存储答案：按钮是否按下

    // 1. 读取输入的5行6列灯状态
    for (int i = 0; i < ROWS; i++) {
        for (int j = 0; j < COLS; j++) {
            cin >> lights[i][j];
        }
    }

    // 2. 穷举第一行的所有可能（共2^6=64种组合）
    for (int mask = 0; mask < (1 << COLS); mask++) {
        // 拷贝原始灯状态，避免修改原数据
        memcpy(grid, lights, sizeof(grid));
        // 初始化按钮矩阵为全0
        memset(buttons, 0, sizeof(buttons));

        // 3. 根据mask设置第一行的按钮并按下
        for (int j = 0; j < COLS; j++) {
            if (mask & (1 << j)) {
                buttons[0][j] = 1;
                press(grid, 0, j);
            }
        }

        // 4. 推导第1~4行的按钮（根据上一行灯的状态）
        for (int i = 1; i < ROWS; i++) {
            for (int j = 0; j < COLS; j++) {
                // 上一行灯亮 → 按下当前行同列按钮熄灭它
                if (grid[i-1][j] == 1) {
                    buttons[i][j] = 1;
                    press(grid, i, j);
                }
            }
        }

        // 5. 检查最后一行是否全部熄灭
        bool success = true;
        for (int j = 0; j < COLS; j++) {
            if (grid[ROWS-1][j] != 0) {
                success = false;
                break;
            }
        }

        // 6. 找到解，输出并退出
        if (success) {
            for (int i = 0; i < ROWS; i++) {
                for (int j = 0; j < COLS; j++) {
                    cout << buttons[i][j] << " ";
                }
                cout << endl;
            }
            return 0;
        }
    }

    return 0;
}