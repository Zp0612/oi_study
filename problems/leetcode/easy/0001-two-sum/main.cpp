class Solution {
public:
    vector<int> twoSum(vector<int>& nums, int target) {
        unordered_map<int, int> mp;
        for (int i = 0; i < nums.size(); i++) {
            int complement = target - nums[i];
            if (mp.find(complement) != mp.end()) {
                return {mp[complement], i};
            }
            mp[nums[i]] = i;
        }
        return {};
    }
};
//OI写法
// #include <iostream>
// #include <vector>
// #include <unordered_map>
// using namespace std;
// int main() {
//     int n, target;
//     cin >> n >> target;      
//     vector<int> nums(n);
//     for (int i = 0; i < n; ++i) {
//         cin >> nums[i];    
//     }
//     unordered_map<int, int> mp;
//     for (int i = 0; i < n; ++i) {
//         int complement = target - nums[i];
//         if (mp.count(complement)) {
//             cout << mp[complement] << " " << i << endl;
//             return 0;
//         }
//         mp[nums[i]] = i;
//     }
//     return 0;
// }