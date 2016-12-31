# ashgraph
Active Sesssion Grapher for Oracle EE  

Example:  
![sample](https://github.com/HideZima/ashgraph/blob/master/ashgraph_1234567890_TESTDB_TESTDB1.png)
## Description
Oracle EE+DiagPackのgv$active_session_historyからOEMの平均アクティブセッションのようなグラフを作成するスクリプトです。　　
たくさんのDBのグラフを並べて表示させたく、作成しました。
グラフはpng形式イメージで出力されます。

## Requirement
Solaris11(x86)上のPerl5.12 + GD::Graph 1.54 + sqlplus(11.2)で動作確認済です。
Perl5にGD::Graph, File::Basename, Cwd, Getopt::Std, strictおよび、これらの前提ライブラリがインストールされている事と、
sqlplusにパスが通っていることと、接続先DBがtnsnames.oraに登録されている必要があります。

## Usage
    Usage: ashgraph.pl [-options]  DBServiceName User Password;
    Options:
    	-c core      : Oracle10gでは、CPUコア数を取得できないため、これを使います。 11g以降は自動取得される為、指定不要です。
    	-d hour      : 時間の表示範囲 規定値：1時間
    	-f filename  : 出力ファイル名 規定値：ashgraph_DBID_DBNAME_INSTANCENAME.png
    	-p directory : 出力先ディレクトリ 規定値：./
    	-i inst_id   : インスタンス番号 (RAC用) 
    	-s skip      : Xラベルのスキップ間隔 規定値：15
    	-h pixel     : イメージの高さ 規定値：135
    	-w pixel     : イメージの幅 規定値：500
    	-y value     : Y座標の最大値 規定値：自動 
    	-L           : 凡例を表示しない
    	-T           : タイトルを表示しない
    	-?           : Help
        
## Install
インストール作業は必要ありませんが、最初の一回はSQLファイルを出力するため、実行ユーザが書き込みできるディレクトリで実行して下さい。
二回目以降の実行はその制限はありません。
