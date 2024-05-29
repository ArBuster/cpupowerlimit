#!/bin/sh

# use intel powercap interface to set cpu powerlimit.

# max_powersave:
max_powersave_pl1=25
max_powersave_pl2=35

# powersave:
powersave_pl1=35
powersave_pl2=45

# balance:
balance_pl1=45
balance_pl2=65

# performance:
performance_pl1=55
performance_pl2=80

# max_performance:
max_performance_pl1=65
max_performance_pl2=90

# PL1 equal PL2:
pep1=55
pep2=60
pep3=65

microwatt=$((10**6))
cpu_vendor=$(grep -m 1 'vendor_id' /proc/cpuinfo | awk -F ': ' '{print $2}')
cpu_num=$(cat /proc/cpuinfo| grep "processor"| wc -l)

function PrintUsage()
{
    local name=`basename $0 .sh`
    echo "Usage: $name [ max_powersave | powersave | balance | performance | max_performance | ${pep1} | ${pep2} | ${pep3} ]"
}

function PrintPowerLimit()
{
    local pl1=$(($(cat /sys/class/powercap/intel-rapl/intel-rapl:0/constraint_0_power_limit_uw) / $microwatt))
    local pl2=$(($(cat /sys/class/powercap/intel-rapl/intel-rapl:0/constraint_1_power_limit_uw) / $microwatt))
    local epp=$(cat /sys/devices/system/cpu/cpufreq/policy0/energy_performance_preference)
    local epb=$(cat /sys/devices/system/cpu/cpu0/power/energy_perf_bias)

    if (($pl1 <= $max_powersave_pl1));then
        echo "max_powersave; PL1: ${pl1}w; PL2: ${pl2}w; epp: ${epp}; epb: ${epb}"
    elif (($pl1 > $max_powersave_pl1 && $pl1 <= $powersave_pl1));then
        echo "powersave; PL1: ${pl1}w; PL2: ${pl2}w; epp: ${epp}; epb: ${epb}"
    elif (($pl1 > $powersave_pl1 && $pl1 <= $balance_pl1));then
        echo "balance; PL1: ${pl1}w; PL2: ${pl2}w; epp: ${epp}; epb: ${epb}"
    elif (($pl1 > $balance_pl1 && $pl1 <= $performance_pl1 && $pl2 > $pep3));then
        echo "performance; PL1: ${pl1}w; PL2: ${pl2}w; epp: ${epp}; epb: ${epb}"
    elif (($pl1 > $performance_pl1 && $pl2 > $pep3));then
        echo "max_performance; PL1: ${pl1}w; PL2: ${pl2}w; epp: ${epp}; epb: ${epb}"
    elif (($pl1 == $pep1 && $pl1 == $pl2));then
        echo "PL1: ${pl1}w; PL2: ${pl2}w; epp: ${epp}; epb: ${epb}"
    elif (($pl1 == $pep2 && $pl1 == $pl2));then
        echo "PL1: ${pl1}w; PL2: ${pl2}w; epp: ${epp}; epb: ${epb}"
    elif (($pl1 == $pep3 && $pl1 == $pl2));then
        echo "PL1: ${pl1}w; PL2: ${pl2}w; epp: ${epp}; epb: ${epb}"
    fi
}

function SetEPP_EPB()
{
    if [ $1 = "epp" ] || (($2 < 0 || $2 > 15));then
        return
    fi

    local epb_array=("power" "balance_power" "default" "balance_performance" "performance")
    local find=false
    for v in ${epb_array[@]}
    do
        if [ $1 = $v ];then
            find=true
        fi
    done

    if [ $find = false ];then
        return
    fi

    for((i=0; i < $cpu_num; i++))
    do
        echo $1 > "/sys/devices/system/cpu/cpufreq/policy${i}/energy_performance_preference"
        echo $2 > "/sys/devices/system/cpu/cpu${i}/power/energy_perf_bias"
    done
}

function SetPowerLimit()
{
    local pl1=0
    local pl2=0
    local epp="epp"
    local epb=-1

    case $1 in
        max_powersave)
            pl1=$max_powersave_pl1
            pl2=$max_powersave_pl2
            epp="power"
            epb=15
            ;;
        powersave)
            pl1=$powersave_pl1
            pl2=$powersave_pl2
            epp="balance_power"
            epb=8
            ;;
        balance)
            pl1=$balance_pl1
            pl2=$balance_pl2
            epp="default"
            epb=6
            ;;
        performance)
            pl1=$performance_pl1
            pl2=$performance_pl2
            epp="balance_performance"
            epb=4
            ;;
        max_performance)
            pl1=$max_performance_pl1
            pl2=$max_performance_pl2
            epp="performance"
            epb=0
            ;;
        $pep1)
            pl1=$pep1
            pl2=$pep1
            epp="performance"
            epb=0
            ;;
        $pep2)
            pl1=$pep2
            pl2=$pep2
            epp="performance"
            epb=0
            ;;
        $pep3)
            pl1=$pep3
            pl2=$pep3
            epp="performance"
            epb=0
            ;;
        *)
            PrintUsage;
            ;;
    esac

    if (($pl1 >= $max_powersave_pl1 && $pl1 <= $max_performance_pl1));then
        echo $(($pl1 * $microwatt)) > /sys/class/powercap/intel-rapl/intel-rapl:0/constraint_0_power_limit_uw
        SetEPP_EPB $epp $epb;
    fi
    
    if (($pl2 >= $max_powersave_pl2 && $pl2 <= $max_performance_pl2));then
        echo $(($pl2 * $microwatt)) > /sys/class/powercap/intel-rapl/intel-rapl:0/constraint_1_power_limit_uw
        SetEPP_EPB $epp $epb;
    fi

    PrintPowerLimit;
    exit 0
}

if [ $cpu_vendor == "GenuineIntel" ]; then
    if [ `whoami` == "root" ]; then
        SetPowerLimit $1;
    else
        case $1 in
            max_powersave|powersave|balance|performance|max_performance|$pep1|$pep2|$pep3)
                echo "Require root privilege."
                ;;
            *)
                PrintUsage;
                ;;
        esac

        PrintPowerLimit;
        exit 2
    fi
else
    echo "only support intel cpu."
fi
