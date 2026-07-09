#include<iostream>
using namespace std;
int main()
{
   int n,m,k;
   cin>>n>>m>>k;
   int A[n][m];
   int B[m][k];
   int C[n][k];

   for(int i=0;i<n;i++)
   {
    for(int j=0;j<m;j++)
    {
        cin>>A[i][j];
    }
   }
   for(int i=0;i<m;i++)
   {
    for(int j=0;j<k;j++)
    {
        cin>>B[i][j];
    }
   }
    for(int i=0;i<n;i++)
    {
     for(int j=0;j<k;j++)
     {
          C[i][j]=0;
          for(int t=0;t<m;t++)
          {
                C[i][j]+=A[i][t]*B[t][j];
          }
     }
    }
    for(int i=0;i<n;i++)
    {
     for(int j=0;j<k;j++)
     {
          cout<<C[i][j]<<" ";
     }
     cout<<endl;
    }
}