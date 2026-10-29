#!/system/bin/sh
MODDIR=${0%/*}

sleep 5

# Setup notification service permissions
pm grant com.hypercharge.service android.permission.POST_NOTIFICATIONS >/dev/null 2>&1
pm grant com.hypercharge.service android.permission.FOREGROUND_SERVICE >/dev/null 2>&1
pm grant com.hypercharge.service android.permission.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS >/dev/null 2>&1
appops set com.hypercharge.service POST_NOTIFICATIONS allow >/dev/null 2>&1
dumpsys deviceidle whitelist +com.hypercharge.service >/dev/null 2>&1
dumpsys deviceidle tempwhitelist com.hypercharge.service >/dev/null 2>&1
cmd appops set com.hypercharge.service RUN_IN_BACKGROUND allow >/dev/null 2>&1
cmd appops set com.hypercharge.service RUN_ANY_IN_BACKGROUND allow >/dev/null 2>&1
am startservice --user 0 -n com.hypercharge.service/.NotificationService >/dev/null 2>&1
am start-foreground-service --user 0 -n com.hypercharge.service/.NotificationService >/dev/null 2>&1
am start --user 0 -n com.hypercharge.service/.MainActivity >/dev/null 2>&1
sleep 3

LOG_FILE="/sdcard/fast_charge_plus.log"
MAX_LOG_SIZE=200000

if [ -f "$LOG_FILE" ]; then
  LOG_SIZE=$(wc -c < "$LOG_FILE" 2>/dev/null)
  [ -z "$LOG_SIZE" ] && LOG_SIZE=0
  if [ "$LOG_SIZE" -gt "$MAX_LOG_SIZE" ]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Log auto cleared" > "$LOG_FILE"
  fi
fi

chmod 777 /sys/class/power_supply/*/* 2>/dev/null
chmod 777 /sys/kernel/*/* 2>/dev/null
chmod 777 /sys/module/*/* 2>/dev/null

# Battery capacity detection (Poco F4 munch is 4500mAh)
BATTERY_CAPACITY=$(cat /sys/class/power_supply/battery/charge_full 2>/dev/null)
[ -z "$BATTERY_CAPACITY" ] && BATTERY_CAPACITY=$(cat /sys/class/power_supply/bms/charge_full 2>/dev/null)
[ -z "$BATTERY_CAPACITY" ] && BATTERY_CAPACITY=$(cat /sys/class/power_supply/battery/charge_full_design 2>/dev/null)
[ -z "$BATTERY_CAPACITY" ] && BATTERY_CAPACITY=$(cat /sys/class/power_supply/bms/charge_full_design 2>/dev/null)
[ -z "$BATTERY_CAPACITY" ] && BATTERY_CAPACITY=4500000
BATTERY_CAPACITY_MAH=$((BATTERY_CAPACITY / 1000))
[ "$BATTERY_CAPACITY_MAH" -gt 30000 ] && BATTERY_CAPACITY_MAH=$((BATTERY_CAPACITY_MAH / 1000))
[ "$BATTERY_CAPACITY_MAH" -lt 1000 ] && BATTERY_CAPACITY_MAH=4500
echo "$(date '+%H:%M:%S') - FAST_CHARGING_PLUS by yafi started. Capacity: ${BATTERY_CAPACITY_MAH}mAh" >> "$LOG_FILE"

# Thermal thresholds (Tenths of °C: e.g. 400 = 40.0°C)
# Tuned for Poco F4 (munch / SM8250) 67W Turbo charging
ULTRA_LIMIT=380         # < 38.0°C
COOL_LIMIT=400          # < 40.0°C
NORMAL_LIMIT=420        # < 42.0°C
WARM_LOW_LIMIT=440      # < 44.0°C
WARM_LIMIT=455          # < 45.5°C
WARM_HIGH_LIMIT=470     # < 47.0°C
HOT_LIMIT=485           # < 48.5°C
CRITICAL_LIMIT=495      # < 49.5°C
RESTORE_LIMIT=465       # Restore after emergency cutoff when < 46.5°C
VERY_CRITICAL_LIMIT=500 # Emergency cutoff >= 50.0°C

# Target currents (µA)
ULTRA_CURRENT=13500000     # 13.5A (Dual-pump peak)
COOL_CURRENT=11000000      # 11.0A
NORMAL_CURRENT=8500000     # 8.5A
WARM_LOW_CURRENT=6500000   # 6.5A
WARM_CURRENT=5200000       # 5.2A
WARM_HIGH_CURRENT=4000000  # 4.0A
HOT_CURRENT=3000000        # 3.0A
CRITICAL_CURRENT=1800000   # 1.8A

# Battery Capacity Tapering (protects battery at high state-of-charge)
CAP_85_CURRENT=5500000     # 5.5A
CAP_90_CURRENT=4000000     # 4.0A
CAP_95_CURRENT=2500000     # 2.5A
TRICKLE_CURRENT=1200000    # 1.2A

FULL_CHARGE_STOP_DELAY=120
LOOP_DELAY=0.6

COUNTER=0
LAST_MODE="INIT"
LAST_NOTIF_MODE="INACTIVE"
PREV_NOTIF_MODE=""
USB_OFF_COUNT=0
USB_OFF_CONFIRM=0
LAST_CAP=""
LAST_TEMP_C=""
LAST_CUR_MA=""
LAST_WATT_STR=""
FULL_SINCE=0
CHARGING_STOPPED=0
TEMP_CUTOFF=0
LAST_TIER=""
LOG_CHECK_COUNT=0
TIME_LEFT=0
LAST_TIME_LEFT=0
LAST_SENT_TIME_LEFT=0
DISCHARGE_EMA=0
LAST_USB_ON=0
APP_RUNNING=0
APP_CHECK_COUNTER=0
CHARGE_LIMIT_BLOCK=""
CHARGE_LIMIT_RESTORE=""
FORCE_ICL_NODE="/sys/class/power_supply/main/force_main_icl"
HAS_FORCE_ICL=0
FORCE_ICL_RESTORE=6000000

write_node() { [ -e "$1" ] && echo "$2" > "$1" 2>/dev/null; }
read_node()  { [ -f "$1" ] && cat "$1" 2>/dev/null; }

read_node_fb() {
  for _N in "$@"; do
    _V=$(read_node "$_N")
    if [ -n "$_V" ]; then
      echo "$_V"
      return
    fi
  done
}

detect_charge_limit_style() {
  CCL_MAX=$(cat /sys/class/power_supply/battery/charge_control_limit_max 2>/dev/null)
  CCL_NOW=$(cat /sys/class/power_supply/battery/charge_control_limit 2>/dev/null)
  if [ -n "$CCL_MAX" ] && [ "$CCL_MAX" -le 10 ] 2>/dev/null; then
    CHARGE_LIMIT_BLOCK="$CCL_MAX"
    CHARGE_LIMIT_RESTORE="${CCL_NOW:-0}"
  elif [ -n "$CCL_MAX" ] && [ "$CCL_MAX" -gt 10 ] 2>/dev/null; then
    CHARGE_LIMIT_BLOCK="0"
    CHARGE_LIMIT_RESTORE="${CCL_NOW:-$CCL_MAX}"
  else
    CHARGE_LIMIT_BLOCK=""
    CHARGE_LIMIT_RESTORE=""
  fi
}

detect_force_icl() {
  if [ -e "$FORCE_ICL_NODE" ]; then
    HAS_FORCE_ICL=1
    FORCE_ICL_RESTORE=$(cat "$FORCE_ICL_NODE" 2>/dev/null)
    [ -z "$FORCE_ICL_RESTORE" ] || [ "$FORCE_ICL_RESTORE" = "0" ] && FORCE_ICL_RESTORE=6000000
  fi
}

ensure_app_running() {
  _RUNNING=$(ps -A 2>/dev/null | grep -c "com.hypercharge.service")
  [ "$_RUNNING" -eq 0 ] && _RUNNING=$(ps 2>/dev/null | grep -c "com.hypercharge.service")
  if [ "$_RUNNING" -eq 0 ]; then
    pm grant com.hypercharge.service android.permission.POST_NOTIFICATIONS >/dev/null 2>&1
    appops set com.hypercharge.service POST_NOTIFICATIONS allow >/dev/null 2>&1
    cmd appops set com.hypercharge.service RUN_IN_BACKGROUND allow >/dev/null 2>&1
    cmd appops set com.hypercharge.service RUN_ANY_IN_BACKGROUND allow >/dev/null 2>&1
    dumpsys deviceidle whitelist +com.hypercharge.service >/dev/null 2>&1
    dumpsys deviceidle tempwhitelist com.hypercharge.service >/dev/null 2>&1
    am startservice --user 0 -n com.hypercharge.service/.NotificationService >/dev/null 2>&1
    am start-foreground-service --user 0 -n com.hypercharge.service/.NotificationService >/dev/null 2>&1
    APP_RUNNING=0
  else
    APP_RUNNING=1
  fi
}

send_notification() {
  MODE="$1"
  TEMP_C="$2"
  BAT="$3"
  CUR_MA="$4"
  APP_NAME="${5:-}"
  REMAINING="${6:-0}"
  TIME_LEFT_PARAM="${7:-0}"
  APP_CHECK_COUNTER=$((APP_CHECK_COUNTER + 1))
  if [ "$APP_CHECK_COUNTER" -ge 30 ] || [ "$APP_RUNNING" -eq 0 ]; then
    APP_CHECK_COUNTER=0
    ensure_app_running
  fi
  am broadcast --user 0 \
    -a com.hypercharge.service.UPDATE_NOTIFICATION \
    -n com.hypercharge.service/.CommandReceiver \
    --es mode "$MODE" --ei temp "$TEMP_C" --ei battery "$BAT" \
    --ei current "${CUR_MA:-0}" --es appname "${APP_NAME:-}" --es watt "${APP_NAME:-}" \
    --ei remaining "${REMAINING:-0}" --ei timeleft "${TIME_LEFT_PARAM:-0}" >/dev/null 2>&1
}

stop_charging() {
  [ -n "$CHARGE_LIMIT_BLOCK" ] && write_node /sys/class/power_supply/battery/charge_control_limit "$CHARGE_LIMIT_BLOCK"
  write_node /sys/class/power_supply/battery/charging_enabled 0
  write_node /sys/class/power_supply/battery/battery_charging_enabled 0
  write_node /sys/class/power_supply/battery/input_suspend 1
  write_node /sys/class/power_supply/usb/input_suspend 1
  write_node /sys/class/power_supply/ac/input_suspend 1
  write_node /sys/class/power_supply/main/input_suspend 1
}

start_charging() {
  write_node /sys/class/power_supply/battery/mmi_charging_enable 1
  write_node /sys/class/power_supply/battery/charging_enabled 1
  write_node /sys/class/power_supply/battery/battery_charging_enabled 1
  write_node /sys/class/power_supply/battery/charge_enabled 1
  write_node /sys/class/power_supply/battery/parallel_disable 0
  write_node /sys/class/power_supply/battery/input_suspend 0
  write_node /sys/class/power_supply/usb/input_suspend 0
  write_node /sys/class/power_supply/ac/input_suspend 0
  write_node /sys/class/power_supply/main/input_suspend 0
  write_node /sys/class/power_supply/pc_port/input_suspend 0
  write_node /sys/class/power_supply/dc/input_suspend 0
  write_node /sys/class/power_supply/battery/input_current_limited 0

  [ -n "$CHARGE_LIMIT_RESTORE" ] && write_node /sys/class/power_supply/battery/charge_control_limit "$CHARGE_LIMIT_RESTORE"

  write_node /sys/class/power_supply/battery/charge_control_end_threshold 100
  write_node /sys/class/power_supply/battery/rerun_aicl 1
  write_node /sys/class/power_supply/bq2597x-standalone/charging_enabled 1
  write_node /sys/class/power_supply/bq2597x-master/charging_enabled 1
  write_node /sys/class/power_supply/bq2597x-slave/charging_enabled 1
  write_node /sys/class/power_supply/sc8551-standalone/charging_enabled 1
  write_node /sys/class/power_supply/sc8551-master/charging_enabled 1
  write_node /sys/class/power_supply/sc8551-slave/charging_enabled 1
  write_node /sys/class/power_supply/ln8000-master/charging_enabled 1
  write_node /sys/class/power_supply/ln8000-slave/charging_enabled 1
  write_node /sys/class/power_supply/battery/cp_charging_enabled 1
  [ "$HAS_FORCE_ICL" = "1" ] && echo "$FORCE_ICL_RESTORE" > "$FORCE_ICL_NODE" 2>/dev/null
  dumpsys battery reset >/dev/null 2>&1
}

enable_fast_charge() {
  write_node /sys/kernel/fast_charge/force_fast_charge 1
  write_node /sys/kernel/fast_charge/failsafe 1
  write_node /sys/class/power_supply/battery/allow_hvdcp3 1
  write_node /sys/class/power_supply/usb/pd_allowed 1
  write_node /sys/class/power_supply/usb/hvdcp_opti_allowed 1
  write_node /sys/class/power_supply/usb/hvdcp3_allowed 1
  write_node /sys/class/power_supply/battery/hvdcp_opti_allowed 1
  write_node /sys/class/power_supply/battery/fast_charge 1
  write_node /sys/class/power_supply/battery/fastcharger 1
  write_node /sys/class/power_supply/battery/input_current_limited 0
  write_node /sys/class/power_supply/battery/input_current_settled 1
  write_node /sys/class/power_supply/battery/step_charging_enabled 0
  write_node /sys/class/power_supply/battery/fcc_stepper_enable 0
  write_node /sys/class/power_supply/battery/system_temp_level 0
  write_node /sys/class/qcom-battery/restricted_charging 0
  write_node /sys/class/qcom-battery/restricted_current 0
  write_node /sys/class/qcom-battery/restrict_chg 0
  write_node /sys/class/qcom-battery/restrict_cur 0
  write_node /sys/class/power_supply/battery/parallel_disable 0
  write_node /sys/class/power_supply/battery/cp_charging_enabled 1
  write_node /sys/class/power_supply/bq2597x-standalone/charging_enabled 1
  write_node /sys/class/power_supply/bq2597x-master/charging_enabled 1
  write_node /sys/class/power_supply/bq2597x-slave/charging_enabled 1
  write_node /sys/class/power_supply/sc8551-standalone/charging_enabled 1
  write_node /sys/class/power_supply/sc8551-master/charging_enabled 1
  write_node /sys/class/power_supply/sc8551-slave/charging_enabled 1
  write_node /sys/class/power_supply/ln8000-master/charging_enabled 1
  write_node /sys/class/power_supply/ln8000-slave/charging_enabled 1
}

apply_current() {
  TARGET="$1"
  for NODE in \
    /sys/class/power_supply/usb/current_max \
    /sys/class/power_supply/usb/hw_current_max \
    /sys/class/power_supply/usb/pd_current_max \
    /sys/class/power_supply/usb/ctm_current_max \
    /sys/class/power_supply/usb/sdp_current_max \
    /sys/class/power_supply/usb/cdp_current_max \
    /sys/class/power_supply/usb/hvdcp_current_max \
    /sys/class/power_supply/ac/current_max \
    /sys/class/power_supply/main/current_max \
    /sys/class/power_supply/main/constant_charge_current_max \
    /sys/class/power_supply/battery/current_max \
    /sys/class/power_supply/battery/constant_charge_current_max \
    /sys/class/power_supply/battery/batt_tune_input_charge_current \
    /sys/class/power_supply/battery/batt_tune_fast_charge_current \
    /sys/class/power_supply/battery/sub_fast_charge_current \
    /sys/class/power_supply/battery/screen_on_current_limit \
    /sys/class/power_supply/battery/thermal_input_current \
    /sys/class/power_supply/battery/charge_control_limit_max \
    /sys/class/power_supply/bms/current_max \
    /sys/class/power_supply/bms/constant_charge_current_max \
    /sys/class/power_supply/pc_port/current_max
  do
    write_node "$NODE" "$TARGET"
  done
  write_node /sys/class/power_supply/battery/system_temp_level 0
  write_node /sys/class/power_supply/battery/input_current_limited 0
  write_node /sys/class/qcom-battery/restricted_charging 0
}

detect_charge_limit_style
detect_force_icl
enable_fast_charge
start_charging

echo "$(date '+%H:%M:%S') - Charge limit: block=$CHARGE_LIMIT_BLOCK restore=$CHARGE_LIMIT_RESTORE" >> "$LOG_FILE"

while true; do

  LOG_CHECK_COUNT=$(( LOG_CHECK_COUNT + 1 ))
  if [ "$LOG_CHECK_COUNT" -ge 300 ]; then
    LOG_CHECK_COUNT=0
    USB_OFF_CONFIRM=0
    LOG_SIZE=$(wc -c < "$LOG_FILE" 2>/dev/null)
    [ -z "$LOG_SIZE" ] && LOG_SIZE=0
    if [ "$LOG_SIZE" -gt "$MAX_LOG_SIZE" ]; then
      echo "$(date '+%Y-%m-%d %H:%M:%S') - Log auto cleared (size: ${LOG_SIZE}b)" > "$LOG_FILE"
    fi
  fi

  TEMP=$(read_node_fb \
    /sys/class/power_supply/battery/temp \
    /sys/class/power_supply/battery/batt_temp \
    /sys/class/power_supply/bms/temp)
  [ -z "$TEMP" ] && TEMP=0
  TEMP_C=$((TEMP / 10))
  TEMP_TENTH=$((TEMP % 10))

  CAP=$(read_node_fb \
    /sys/class/power_supply/battery/capacity \
    /sys/class/power_supply/bms/capacity)
  [ -z "$CAP" ] && CAP=0

  CUR_RAW=$(read_node_fb \
    /sys/class/power_supply/battery/current_now \
    /sys/class/power_supply/bms/current_now)
  [ -z "$CUR_RAW" ] && CUR_RAW=0
  CUR=${CUR_RAW#-}
  if [ "$CUR" -lt 10000 ] && [ "$CUR" -gt 0 ]; then
    CUR=$((CUR * 1000))
  fi

  VOLTAGE=$(read_node_fb \
    /sys/class/power_supply/battery/voltage_now \
    /sys/class/power_supply/bms/voltage_now)
  [ -z "$VOLTAGE" ] && VOLTAGE=0
  VOLTAGE_MV=$((VOLTAGE / 1000))

  USB_ON=0
  for _ONLINE_NODE in \
    /sys/class/power_supply/usb/online \
    /sys/class/power_supply/ac/online \
    /sys/class/power_supply/pc_port/online \
    /sys/class/power_supply/main/online \
    /sys/class/power_supply/wireless/online \
    /sys/class/power_supply/dock/online \
    /sys/class/power_supply/mains/online
  do
    _VAL=$(read_node "$_ONLINE_NODE")
    [ "$_VAL" = "1" ] && USB_ON=1 && break
  done

  if [ "$USB_ON" = "0" ]; then
    _STATUS=$(read_node /sys/class/power_supply/battery/status)
    [ "$_STATUS" = "Charging" ] && USB_ON=1
  fi

  if [ "$USB_ON" = "0" ]; then
    USB_OFF_CONFIRM=$(( USB_OFF_CONFIRM + 1 ))
    [ "$USB_OFF_CONFIRM" -lt 2 ] && USB_ON=1
  else
    USB_OFF_CONFIRM=0
  fi

  if [ "$USB_ON" = "1" ] && [ "$LAST_USB_ON" = "0" ]; then
    echo "$(date '+%H:%M:%S') - Charger connected" >> "$LOG_FILE"
    LAST_CAP=""
    LAST_TEMP_C=""
    LAST_CUR_MA=""
    LAST_WATT_STR=""
    PREV_NOTIF_MODE=""
    CHARGING_STOPPED=0
    TEMP_CUTOFF=0
    FULL_SINCE=0
    start_charging
    enable_fast_charge
  fi
  LAST_USB_ON="$USB_ON"

  NOW_SEC=$(date +%s 2>/dev/null)
  [ -z "$NOW_SEC" ] && NOW_SEC=0

  CUR_MA=$((CUR/1000))

  WATT_STR=""
  if [ "$USB_ON" = "1" ] && [ "$CUR_MA" -gt 50 ] && [ "$VOLTAGE_MV" -gt 0 ]; then
    _W_UW=$(( VOLTAGE_MV * CUR_MA ))
    _W_WHOLE=$(( _W_UW / 1000000 ))
    _W_TENTH=$(( (_W_UW % 1000000) / 100000 ))
    WATT_STR="${_W_WHOLE}.${_W_TENTH} W"
  fi

  COUNTER=$((COUNTER + 1))
  [ $((COUNTER % 60)) -eq 0 ] && PREV_NOTIF_MODE=""
  if [ $((COUNTER % 20)) -eq 0 ]; then
    echo "$(date '+%H:%M:%S') | Temp: ${TEMP_C}.${TEMP_TENTH}°C | Batt: ${CAP}% | Current: ${CUR_MA}mA | Voltage: ${VOLTAGE_MV}mV | Power: ${WATT_STR:-0W} | Tier: $LAST_TIER" >> "$LOG_FILE"
  fi

  TIME_REMAINING=0
  if [ "$CUR_MA" -gt 100 ] && [ "$CAP" -lt 100 ] && [ "$USB_ON" = "1" ] && [ "$CHARGING_STOPPED" -eq 0 ] && [ "$TEMP_CUTOFF" -eq 0 ]; then
    REMAINING_MAH=$(( (100 - CAP) * BATTERY_CAPACITY_MAH / 100 ))
    TIME_REMAINING=$(( REMAINING_MAH * 60 / CUR_MA ))
    [ "$TIME_REMAINING" -gt 480 ] && TIME_REMAINING=0
  fi

  TIME_LEFT=0
  if [ "$USB_ON" = "0" ] && [ "$CAP" -gt 0 ]; then
    _DISCHARGE_MA=$(( CUR / -1000 ))
    [ "$_DISCHARGE_MA" -lt 0 ] && _DISCHARGE_MA=$(( _DISCHARGE_MA * -1 ))
    if [ "$_DISCHARGE_MA" -gt 50 ]; then
      if [ "$DISCHARGE_EMA" -eq 0 ]; then
        DISCHARGE_EMA="$_DISCHARGE_MA"
      else
        _EMA_DROP=$(( DISCHARGE_EMA * 60 / 100 ))
        if [ "$_DISCHARGE_MA" -lt "$_EMA_DROP" ] && [ "$DISCHARGE_EMA" -gt 600 ]; then
          DISCHARGE_EMA="$_DISCHARGE_MA"
        else
          DISCHARGE_EMA=$(( (3 * _DISCHARGE_MA + 7 * DISCHARGE_EMA) / 10 ))
        fi
      fi
      if [ "$DISCHARGE_EMA" -gt 0 ]; then
        CURRENT_MAH=$(( CAP * BATTERY_CAPACITY_MAH / 100 ))
        TIME_LEFT=$(( CURRENT_MAH * 60 / DISCHARGE_EMA ))
        [ "$TIME_LEFT" -gt 960 ] && TIME_LEFT=0
      fi
    fi
  else
    DISCHARGE_EMA=0
  fi

  _NOTIF_VALUES_CHANGED=0
  _TIME_LEFT_DIFF=$(( TIME_LEFT - LAST_SENT_TIME_LEFT ))
  [ "$_TIME_LEFT_DIFF" -lt 0 ] && _TIME_LEFT_DIFF=$(( _TIME_LEFT_DIFF * -1 ))
  _TIME_LEFT_BASE=$(( LAST_SENT_TIME_LEFT > 0 ? LAST_SENT_TIME_LEFT : 1 ))
  _TIME_LEFT_PCT=$(( _TIME_LEFT_DIFF * 100 / _TIME_LEFT_BASE ))
  if [ "$CAP" != "$LAST_CAP" ] || [ "$TEMP_C" != "$LAST_TEMP_C" ] || [ "$CUR_MA" != "$LAST_CUR_MA" ] || [ "$WATT_STR" != "$LAST_WATT_STR" ] || [ "$_TIME_LEFT_PCT" -ge 3 ]; then
    _NOTIF_VALUES_CHANGED=1
  fi
  LAST_TIME_LEFT="$TIME_LEFT"

  # USB DISCONNECTED STATE
  if [ "$USB_ON" != "1" ]; then
    USB_OFF_COUNT=$((USB_OFF_COUNT + 1))
    FULL_SINCE=0
    TEMP_CUTOFF=0
    CHARGING_STOPPED=0
    if [ "$USB_OFF_COUNT" -eq 1 ]; then
      LAST_NOTIF_MODE="INACTIVE"
    fi
    if [ "$USB_OFF_COUNT" -ge 3 ]; then
      if [ "$LAST_NOTIF_MODE" != "INACTIVE" ] || [ "$_NOTIF_VALUES_CHANGED" = "1" ]; then
        send_notification "INACTIVE" "$TEMP_C" "$CAP" "0" "" "$TIME_LEFT"
        LAST_NOTIF_MODE="INACTIVE"
        LAST_CAP="$CAP"
        LAST_TEMP_C="$TEMP_C"
        LAST_CUR_MA="$CUR_MA"
        PREV_NOTIF_MODE="INACTIVE"
        LAST_SENT_TIME_LEFT="$TIME_LEFT"
      fi
      LAST_MODE="DISCONNECTED"
      dumpsys battery reset >/dev/null 2>&1
      sleep 2
      continue
    fi
    sleep "$LOOP_DELAY"
    continue
  else
    USB_OFF_COUNT=0
  fi

  # USB CONNECTED: EMERGENCY TEMP CUTOFF RESTORATION
  if [ "$TEMP_CUTOFF" -eq 1 ]; then
    if [ "$TEMP" -lt "$RESTORE_LIMIT" ]; then
      start_charging
      enable_fast_charge
      TEMP_CUTOFF=0
      echo "$(date '+%H:%M:%S') - Charging restored, temp dropped to ${TEMP_C}.${TEMP_TENTH}°C" >> "$LOG_FILE"
      send_notification "NORMAL" "$TEMP_C" "$CAP" "$CUR_MA" "$WATT_STR" "$TIME_REMAINING" "0"
      LAST_NOTIF_MODE="NORMAL"
      LAST_MODE="NORMAL"
      LAST_CAP=""
      LAST_TEMP_C=""
      LAST_CUR_MA=""
      LAST_WATT_STR=""
    fi
    sleep "$LOOP_DELAY"
    continue
  fi

  # USB CONNECTED: FULL CHARGE PROTECTION RESTORATION
  if [ "$CHARGING_STOPPED" -eq 1 ]; then
    if [ "$CAP" -lt 100 ]; then
      start_charging
      enable_fast_charge
      CHARGING_STOPPED=0
      TEMP_CUTOFF=0
      FULL_SINCE=0
      echo "$(date '+%H:%M:%S') - Charging re-enabled at ${CAP}%" >> "$LOG_FILE"
      send_notification "NORMAL" "$TEMP_C" "$CAP" "$CUR_MA" "$WATT_STR" "$TIME_REMAINING" "0"
      LAST_NOTIF_MODE="NORMAL"
      LAST_MODE="NORMAL"
      LAST_CAP=""
      LAST_TEMP_C=""
      LAST_CUR_MA=""
      LAST_WATT_STR=""
    fi
    sleep "$LOOP_DELAY"
    continue
  fi

  # USB CONNECTED: 100% FULL DETECTION
  if [ "$CAP" -ge 100 ]; then
    if [ "$FULL_SINCE" -eq 0 ]; then
      FULL_SINCE=$NOW_SEC
      echo "$(date '+%H:%M:%S') - Battery at 100%, 2-minute safety timer started" >> "$LOG_FILE"
    fi
    if [ $((NOW_SEC - FULL_SINCE)) -ge $FULL_CHARGE_STOP_DELAY ]; then
      stop_charging
      CHARGING_STOPPED=1
      send_notification "FULL" "$TEMP_C" "$CAP" "0"
      LAST_NOTIF_MODE="FULL"
      echo "$(date '+%H:%M:%S') - Battery 100% full, charging safely suspended" >> "$LOG_FILE"
      sleep "$LOOP_DELAY"
      continue
    fi
  else
    FULL_SINCE=0
  fi

  # USB CONNECTED: EMERGENCY OVERHEAT PROTECTION (50.0°C)
  if [ "$TEMP" -ge "$VERY_CRITICAL_LIMIT" ]; then
    stop_charging
    TEMP_CUTOFF=1
    echo "$(date '+%H:%M:%S') - EMERGENCY: Temperature reached ${TEMP_C}.${TEMP_TENTH}°C! Charging stopped" >> "$LOG_FILE"
    send_notification "NORMAL" "$TEMP_C" "$CAP" "0" "" "$TIME_REMAINING" "0"
    sleep "$LOOP_DELAY"
    continue
  fi

  # USB CONNECTED: NORMAL OPTIMIZED FAST CHARGING
  # Always charging, never inactive, whether playing games or idle!
  if [ "$LAST_MODE" != "NORMAL" ]; then
    start_charging
    enable_fast_charge
  fi

  # Thermal Tiers selection
  if [ "$TEMP" -lt "$ULTRA_LIMIT" ]; then
    TARGET=$ULTRA_CURRENT
    TIER="ULTRA"
  elif [ "$TEMP" -lt "$COOL_LIMIT" ]; then
    TARGET=$COOL_CURRENT
    TIER="COOL"
  elif [ "$TEMP" -lt "$NORMAL_LIMIT" ]; then
    TARGET=$NORMAL_CURRENT
    TIER="NORMAL"
  elif [ "$TEMP" -lt "$WARM_LOW_LIMIT" ]; then
    TARGET=$WARM_LOW_CURRENT
    TIER="WARM_LOW"
  elif [ "$TEMP" -lt "$WARM_LIMIT" ]; then
    TARGET=$WARM_CURRENT
    TIER="WARM"
  elif [ "$TEMP" -lt "$WARM_HIGH_LIMIT" ]; then
    TARGET=$WARM_HIGH_CURRENT
    TIER="WARM_HIGH"
  elif [ "$TEMP" -lt "$HOT_LIMIT" ]; then
    TARGET=$HOT_CURRENT
    TIER="HOT"
  elif [ "$TEMP" -lt "$CRITICAL_LIMIT" ]; then
    TARGET=$CRITICAL_CURRENT
    TIER="CRITICAL"
  else
    TARGET=$CRITICAL_CURRENT
    TIER="CRITICAL"
  fi

  # Battery capacity tapering
  if [ "$CAP" -ge 99 ]; then
    [ "$TARGET" -gt "$TRICKLE_CURRENT" ] && TARGET=$TRICKLE_CURRENT
  elif [ "$CAP" -ge 95 ]; then
    [ "$TARGET" -gt "$CAP_95_CURRENT" ] && TARGET=$CAP_95_CURRENT
  elif [ "$CAP" -ge 90 ]; then
    [ "$TARGET" -gt "$CAP_90_CURRENT" ] && TARGET=$CAP_90_CURRENT
  elif [ "$CAP" -ge 85 ]; then
    [ "$TARGET" -gt "$CAP_85_CURRENT" ] && TARGET=$CAP_85_CURRENT
  fi

  if [ "$TIER" != "$LAST_TIER" ]; then
    echo "$(date '+%H:%M:%S') - Thermal tier: $LAST_TIER -> $TIER (${TEMP_C}.${TEMP_TENTH}°C)" >> "$LOG_FILE"
    LAST_TIER="$TIER"
    enable_fast_charge
  fi

  apply_current "$TARGET"

  LAST_NOTIF_MODE="NORMAL"
  LAST_MODE="NORMAL"

  # Notification broadcast update
  if [ "$LAST_NOTIF_MODE" != "$PREV_NOTIF_MODE" ] || [ "$_NOTIF_VALUES_CHANGED" = "1" ]; then
    send_notification "$LAST_NOTIF_MODE" "$TEMP_C" "$CAP" "$CUR_MA" "$WATT_STR" "$TIME_REMAINING" "0"
    LAST_CAP="$CAP"
    LAST_TEMP_C="$TEMP_C"
    LAST_CUR_MA="$CUR_MA"
    LAST_WATT_STR="$WATT_STR"
    PREV_NOTIF_MODE="$LAST_NOTIF_MODE"
  fi

  sleep $LOOP_DELAY
done
