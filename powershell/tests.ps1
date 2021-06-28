function test {

    write-host $param1 "=>" $param2

}

function helping {

    write-host "
                on entre bien dans la
                boucle de l'aide
                "
}

$param1 = $args[0]
$param2 = $args[1]

switch ($param1,$param2)
{
   {@("Disabled", "Enabled") -notcontains $param1} {helping;break}
   {@("Disabled", "Enabled") -notcontains $param2} {helping;break}
   default {test;break}
}
