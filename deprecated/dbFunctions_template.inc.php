<?php 
$db="[YOUR DB NAME]";
//set up RDS $host values here to be used in the code
$host_prod4 = '[YOUR HOST - RDS WRITER INSTANCE ENDPOINT]';
$host_prod4ro = '[YOUR HOST - RDS READER INSTANCE ENDPOINT]';  //set this to the same as above if not using reader instance

function connect_to_db($db,$host='[YOUR HOST - RDS WRITER INSTANCE ENDPOINT AS DEFAULT]') {
	return pg_connect(sprintf("host=$host dbname=$db user=[YOUR DB USER] password=[YOUR DB USER PASSWORD]"));
}

function query_db($db,$sql,$host='[YOUR HOST - RDS WRITER INSTANCE ENDPOINT AS DEFAULT]') {
	if (!$connect_db) {$connect_db = connect_to_db($db,$host); }
	if (!$connect_db) { echo "Could not connect"; exit; } 
	$result=pg_exec($connect_db,$sql);
	return $result;
}

function close_db() {
	if ($connect_db) {pg_close($connect_db);}
}

function get_array_from_db($db,$sql,$host='[YOUR HOST - RDS WRITER INSTANCE ENDPOINT AS DEFAULT]')
{
    return pg_fetch_all(query_db($db,$sql,$host));
    close_db();
}

function get_value_from_db($db,$sql,$host='[YOUR HOST - RDS WRITER INSTANCE ENDPOINT AS DEFAULT]')
{
    return pg_fetch_result(query_db($db,$sql,$host), 0, 0);
    close_db();
}

function exec_sql($db,$sql,$host='[YOUR HOST - RDS WRITER INSTANCE ENDPOINT AS DEFAULT]')
{
    query_db($db,$sql,$host);
    close_db();
}
?>
