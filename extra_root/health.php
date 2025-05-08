<?php

use Leantime\Core\Db\Db as DbCore;

Class health
{
    public function __construct(
        protected DbCore $db
    ) {}

    public function getHealth(): void
    {

        $sql = 'SELECT COUNT(VERSION());';

        $stmn = $this->db->database->prepare($sql);

        $stmn->execute();
        $sql_live = $stmn->fetchColumn();
        $stmn->closeCursor();

        if($sql_live > 0)
        {
            http_response_code(200);
            echo "Ok: ".$sql_live;
        }
        else
        {
            http_response_code(500);
            echo "NotOk: ".$sql_live;
        }
    }

}

$healthObject = new health();
$healthObject->getHealth();

?>
