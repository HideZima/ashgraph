# ashgraph
Active Sesssion Grapher for Oracle EE

## Description
Oracle EE+DiagPackのgv$active_session_historyからOEMの平均アクティブセッションのようなグラフを作成するスクリプトです。
たくさんのDBのOEMのグラフを並べて表示させたい為に作成しました。
グラフはpng形式イメージで出力されます。

## Requirement
Solaris11(x86)上のPerl5.12 + GD::Graph 1.54 + sqlplus(11.2)で動作確認済です。
Perl5にGD::Graph, File::Basename, Cwd, Getopt::Std, strictおよび、これらの前提ライブラリがインストールされている事と、
sqlplusにパスが通っていることと、接続先DBがtnsnames.oraに登録されている必要があります。

## Usage
    Usage: ashgraph.pl [-options]  DBServiceName User Password;
    Output file name: 
    	ashgraph_DBID_DBNAME_INSTANCENAME.png
    Options:
    	-c core      : CPU core for Oracle10g 
    	-d hour      : duration  
    	-f filename  : output file name 
    	-p directory : output directory 
    	-i inst_id   : inst_id for RAC 
    	-s skip      : X label skip
    	-h pixel     : height         
    	-w pixel     : width 
    	-y value     : Y max value 
    	-L           : No Legends 
    	-T           : No Title 
    	-?           : Help 
