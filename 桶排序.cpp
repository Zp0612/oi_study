#include <bits/stdc++.h>
using namespace std;

void bucketSort(vector<int> &a) {
    if (a.empty()) return;
    int n = a.size();
    int minv = *min_element(a.begin(), a.end());
    int maxv = *max_element(a.begin(), a.end());
    int range = maxv - minv + 1;
    int bucketCount = max(1, n);
    vector<vector<int>> buckets(bucketCount);
    for (int x : a) {
        int idx = (long long)(x - minv) * (bucketCount - 1) / max(1, range - 1);
        buckets[idx].push_back(x);
    }
    int pos = 0;
    for (auto &b : buckets) {
        sort(b.begin(), b.end());
        for (int x : b) {
            a[pos++] = x;
        }
    }
}

int main() {
    ios::sync_with_stdio(false);
    cin.tie(NULL);

    int n;
    if (!(cin >> n)) return 0;
    vector<int> a(n);
    for (int i = 0; i < n; i++) {
        cin >> a[i];
    }
    bucketSort(a);
    for (int i = 0; i < n; i++) {
        cout << a[i];
        if (i + 1 < n) cout << ' ';
    }
    cout << '\n';
    return 0;
}
