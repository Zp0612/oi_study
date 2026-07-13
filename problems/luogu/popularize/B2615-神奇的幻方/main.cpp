#include<iostream>

using namespace std;

const int MAXN = 40;  

int main()
{
  int N;
    cin >> N;
  int A[MAXN][MAXN] = {0};
    A[0][N/2] = 1;
    int row=0,col=N/2;
    for(int K = 2; K <= N*N; K++)
    {
       int new_row,new_col;
       //规则1
       if(row==0&&col!=N-1)
       {
           new_row = N-1;
           new_col = col+1;
       }
       //规则2
       else if(row!=0&&col==N-1)
       {
           new_row = row-1;
           new_col = 0;
       }
       //规则3
       else if(row==0&&col==N-1)
       {
           new_row = row+1;
           new_col = col;
       }
       //规则4
       else if(row!=0&&col!=N-1)
       {
          if(A[row-1][col+1]==0)
          { 
            new_row = row-1;
            new_col = col+1;
          }
          else
          {
            new_row = row+1;
            new_col = col;
          }
       }
       A[new_row][new_col] = K;
       row = new_row;
       col = new_col;
    }
    for(int i=0;i<N;i++)
    {
       for(int j=0;j<N;j++)
       {
          cout << A[i][j] << " ";
       }
       cout << endl;
    }
    return 0;
}