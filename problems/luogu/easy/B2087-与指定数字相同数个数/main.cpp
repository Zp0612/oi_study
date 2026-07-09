#include<iostream>
using namespace std;
int main()
{
   int n;
   scanf("%d",&n);
   int a[101];
   for(int i=0;i<n;i++)
    {
         scanf("%d",&a[i]);
    }
    int m;
    scanf("%d",&m);
    int count = 0;
    for(int i=0;i<n;i++)
    {
        if(a[i] == m)
        {
            count++;
        }
    }
    printf("%d\n",count);
    return 0;
}