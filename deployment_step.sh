#!/bin/bash

PROJECT="apptivo-app-stag"
GCR="us.gcr.io"
NNAME="profit" 
WAR_NAME="app.war"
NAMESPACE="us"
Node=$1
Node_Label=$2
bg=$3
ENVIRONMENT=$5
FILE_VERSION=$6
FC_VERSION_NOTIFY=$7
REQUIRED=$8
##########################
if [[ $ENVIRONMENT = "UAT" ]]; then
GCHAT_URL='https://chat.googleapis.com/v1/spaces/AAAAkRPquRE/messages?key=AIzaSyDdI0hCZtE6vySjMm-WEfRq3CPzqKqqsHI&token=8P_S4Exea74xKAFnKua2-q7Tnaawpkk7hwhESi8L4f0%3D&messageReplyOption=REPLY_MESSAGE_FALLBACK_TO_NEW_THREAD'
	        ###sathish chat#####
#     GCHAT_URL="https://chat.googleapis.com/v1/spaces/AAAAi3EHuzc/messages?key=AIzaSyDdI0hCZtE6vySjMm-WEfRq3CPzqKqqsHI&token=0DGw9aqpUU_gLD7edRTR_PKDdLwS3f6ZXZuwQtg4H3E%3D&messageReplyOption=REPLY_MESSAGE_FALLBACK_TO_NEW_THREAD"
else
#	GCHAT_URL='https://chat.googleapis.com/v1/spaces/AAAA2ii6fn8/messages?key=AIzaSyDdI0hCZtE6vySjMm-WEfRq3CPzqKqqsHI&token=WA7z-fCdxStQJpkHETZf-FXYHf4ugwtLQT48ktSgAjc%3D&messageReplyOption=REPLY_MESSAGE_FALLBACK_TO_NEW_THREAD'
      GCHAT_URL="https://chat.googleapis.com/v1/spaces/AAAA2ii6fn8/messages?key=AIzaSyDdI0hCZtE6vySjMm-WEfRq3CPzqKqqsHI&token=WA7z-fCdxStQJpkHETZf-FXYHf4ugwtLQT48ktSgAjc&messageReplyOption=REPLY_MESSAGE_FALLBACK_TO_NEW_THREAD"

fi

send_alert() {
	curl -sH 'Content-Type: application/json' -X POST $GCHAT_URL --data '{"text": "*Docker Image Deployment Failed for Profit Node*", "thread" : { "threadKey": "THREAD-'$(date +%s)'"}}' >> /dev/null
}

trap 'send_alert; exit 1' ERR

APP_DEPLOY()
{
    NAME=""$Node"_App"
    START_TIME=`date +%s`
    STS="$Node-app"
    LABEL="$Node_Label-app"
    CLUSTER_NAME="GUI Cluster"
    GUI_CONTEXT="gke_apptivo-app-stag_us-central1-c_us-gui-gke-cluster"
    GUI_THREAD=gui-thread-$START_TIME
   # GCHAT_URL="https://chat.googleapis.com/v1/spaces/AAAA2ii6fn8/messages?key=AIzaSyDdI0hCZtE6vySjMm-WEfRq3CPzqKqqsHI&token=WA7z-fCdxStQJpkHETZf-FXYHf4ugwtLQT48ktSgAjc%3D&messageReplyOption=REPLY_MESSAGE_FALLBACK_TO_NEW_THREAD"
    #kubectl config use-context gke_apptivo-app-stag_us-central1-c_us-gui-gke-cluster || exit 1

    #Login to GKE Cluster
    echo -e "\n"
    #echo -e "============================"
    echo -e "8. Connecting to $CLUSTER_NAME"
    echo -e "-----------------------------------"

    curl -sH 'Content-Type: application/json' -X POST $GCHAT_URL --data '{"text": "Deployment Started on '$NAME' Node", "thread" : {"threadKey": "'"$GUI_THREAD"'"}}' >> /dev/null

    #FIND Number of pods running
    TOTAL_PODS=`kubectl get pod -l app=$LABEL -n $NAMESPACE --context=$GUI_CONTEXT | tail -n +2 | wc -l`

    echo -e "\nTotally $TOTAL_PODS pod found\n"

    if [[ $TOTAL_PODS -gt 0 ]]; then
        for ((i=0,j=$TOTAL_PODS;i<j;i++));do

            #echo -e "======================="
            echo -e "9. Deploying $STS-$i pod "
            echo -e "-----------------------------"
            echo -e "\n"
            curl -sH 'Content-Type: application/json' -X POST $GCHAT_URL --data '{"text": "Deployment Initiated on '$STS'-'$i' Node", "thread" : {"threadKey": "'"$GUI_THREAD"'"}}' >> /dev/null

            kubectl label pod $STS-$i enabled=false --overwrite -n $NAMESPACE --context=$GUI_CONTEXT || exit 1
            kubectl delete pod $STS-$i -n $NAMESPACE --context=$GUI_CONTEXT && sleep 10 || exit 1

            while true
            do
                k=$(( $i + 1 ))
                RUNNING_PODS=`kubectl get pod -l app=$LABEL -n $NAMESPACE --context=$GUI_CONTEXT | tail -n +2 | awk -F " " 'NR=='$k'{print $2}'`
                RUNNING_STATUS=`kubectl get pod -l app=$LABEL -n $NAMESPACE --context=$GUI_CONTEXT | tail -n +2 | awk -F " " 'NR=='$k'{print $3}'`

                if { [[ $RUNNING_PODS == 1/1 ]] || [[ $RUNNING_PODS == 2/2 ]]; } && [[ $RUNNING_STATUS == Running ]]; then
                    echo -e "\nPod $STS-$i is Bounced and Running\n"
		            ID=`kubectl exec -it $STS-$i -n $NAMESPACE --context=$GUI_CONTEXT -- md5sum live/$NNAME/webapps/$WAR_NAME | awk '{print $1}'`
                    curl -sH 'Content-Type: application/json' -X POST $GCHAT_URL --data '{"text": "Md5sum of Running Pod '$STS'-'$i' is '$ID'", "thread" : {"threadKey": "'"$GUI_THREAD"'"}}' >> /dev/null
                    echo -e "=================================================================="
                    echo -e "\nRunning Pod $STS-$i MD5SUM is" `kubectl exec -it $STS-$i -n $NAMESPACE --context=$GUI_CONTEXT -- md5sum live/$NNAME/webapps/$WAR_NAME | awk '{print $1}'`
                    echo -e "=================================================================="
                    echo -e "\n"
                    ID=`kubectl exec -it $STS-$i -n $NAMESPACE --context=$GUI_CONTEXT -- md5sum live/$NNAME/webapps/$WAR_NAME | awk '{print $1}'`
                    curl -sH 'Content-Type: application/json' -X POST $GCHAT_URL --data '{"text": "Deployment done on '$STS'-'$i' Node", "thread" : {"threadKey": "'"$GUI_THREAD"'"}}' >> /dev/null
                    break
                else    
                    sleep 5
                fi
            done
        done
    else
        echo "################################################xxxxxxx"
        echo "There is no pod Running. Please contact Cloud Team"
        echo "################################################xxxxxxx"
        echo -e "\n"
        exit 1;
    fi

	    END_TIME=`date +%s`
	    RUNTIME=$((END_TIME-START_TIME))
	    TOTAL_MINS=$((RUNTIME / 60))
	    TOTAL_SEC=$((RUNTIME % 60))

	    echo -e "\nTotal Time taken for $STS Deployment $TOTAL_MINS minutes $TOTAL_SEC seconds"
	    curl -sH 'Content-Type: application/json' -X POST $GCHAT_URL --data '{"text": "Docker Deployment done on '$NAME' Node", "thread" : { "threadKey": "'"$GUI_THREAD"'"}}' >> /dev/null

}

sleep 2

API_DEPLOY()
{
    NAME=""$Node"_Profit_Api"
    START_TIME=`date +%s`
    STS="$Node-$bg"
    LABEL="$Node_Label-api"
    CLUSTER_NAME="BG Cluster"
    BG_THREAD=bg-thread-$START_TIME
    BG_CONTEXT="gke_apptivo-app-stag_us-central1-c_us-bg-gke-cluster"
   # GCHAT_URL="https://chat.googleapis.com/v1/spaces/AAAA2ii6fn8/messages?key=AIzaSyDdI0hCZtE6vySjMm-WEfRq3CPzqKqqsHI&token=WA7z-fCdxStQJpkHETZf-FXYHf4ugwtLQT48ktSgAjc%3D&messageReplyOption=REPLY_MESSAGE_FALLBACK_TO_NEW_THREAD"
    #kubectl config use-context gke_apptivo-app-stag_us-central1-c_us-bg-gke-cluster || exit 1

    #Login to GKE Cluster
    echo -e "\n"
    #echo -e "============================"
    echo -e "8. Connecting to $CLUSTER_NAME"
    echo -e "-----------------------------------"

    curl -sH 'Content-Type: application/json' -X POST $GCHAT_URL --data '{"text": "Deployment Started on '$NAME' Node", "thread" : {"threadKey": "'"$BG_THREAD"'"}}' >> /dev/null

    #FIND Number of pods running
    TOTAL_PODS=`kubectl get pod -l app=$LABEL -n $NAMESPACE --context=$BG_CONTEXT| tail -n +2 | wc -l`

    echo -e "\nTotally $TOTAL_PODS pod found\n"

    if [[ $TOTAL_PODS -gt 0 ]]; then
        for ((i=0,j=$TOTAL_PODS;i<j;i++));do

            #echo -e "======================="
            echo -e "9. Deploying $STS-$i pod "
            echo -e "-----------------------------"
            echo -e "\n"
            curl -sH 'Content-Type: application/json' -X POST $GCHAT_URL --data '{"text": "Deployment Initiated on '$STS'-'$i' Node", "thread" : {"threadKey": "'"$BG_THREAD"'"}}' >> /dev/null

            kubectl label pod $STS-$i enabled=false --overwrite -n $NAMESPACE --context=$BG_CONTEXT || exit 1
            kubectl delete pod $STS-$i -n $NAMESPACE --context=$BG_CONTEXT && sleep 10 || exit 1

            while true
            do
                k=$(( $i + 1 ))
                RUNNING_PODS=`kubectl get pod -l app=$LABEL -n $NAMESPACE --context=$BG_CONTEXT | tail -n +2 | awk -F " " 'NR=='$k'{print $2}'`
                RUNNING_STATUS=`kubectl get pod -l app=$LABEL -n $NAMESPACE --context=$BG_CONTEXT | tail -n +2 | awk -F " " 'NR=='$k'{print $3}'`

                if [[ "$RUNNING_PODS" == "1/1" || "$RUNNING_PODS" == "2/2" ]] && [[ $RUNNING_STATUS == Running ]]; then
                    echo -e "\nPod $STS-$i is Bounced and Running\n"
		            ID=`kubectl exec -it $STS-$i -n $NAMESPACE --context=$BG_CONTEXT -- md5sum live/$NNAME/webapps/$WAR_NAME | awk '{print $1}'`
                    curl -sH 'Content-Type: application/json' -X POST $GCHAT_URL --data '{"text": "Md5sum of Running Pod '$STS'-'$i' is '$ID'", "thread" : {"threadKey": "'"$BG_THREAD"'"}}' >> /dev/null
                    echo -e "=================================================================="
                    echo -e "\nRunning Pod $STS-$i MD5SUM is" `kubectl exec -it $STS-$i -n $NAMESPACE --context=$BG_CONTEXT -- md5sum live/$NNAME/webapps/$WAR_NAME | awk '{print $1}'`
                    echo -e "=================================================================="
                    echo -e "\n"
                    ID=`kubectl exec -it $STS-$i -n $NAMESPACE --context=$BG_CONTEXT -- md5sum live/$NNAME/webapps/$WAR_NAME | awk '{print $1}'`
                    curl -sH 'Content-Type: application/json' -X POST $GCHAT_URL --data '{"text": "Deployment done on '$STS'-'$i' Node", "thread" : {"threadKey": "'"$BG_THREAD"'"}}' >> /dev/null
                    break
                else    
                    sleep 5
                fi
            done
        done
    else
        echo "################################################xxxxxxx"
        echo "There is no pod Running. Please contact Cloud Team"
        echo "################################################xxxxxxx"
        echo -e "\n"
        exit 1;
    fi

    END_TIME=`date +%s`
    RUNTIME=$((END_TIME-START_TIME))
    TOTAL_MINS=$((RUNTIME / 60))
    TOTAL_SEC=$((RUNTIME % 60))

    echo -e "\nTotal Time taken for $STS Deployment $TOTAL_MINS minutes $TOTAL_SEC seconds"
    curl -sH 'Content-Type: application/json' -X POST $GCHAT_URL --data '{"text": "Docker Deployment done on '$NAME' Node", "thread" : { "threadKey": "'"$BG_THREAD"'"}}' >> /dev/null

}

sleep 2

APP_DEPLOY &
API_DEPLOY &
wait

sleep 2

#curl -sH 'Content-Type: application/json' -X POST $GCHAT_URL --data '{"text": "*Docker Image Deployment Completed for Profit Nodes*", "thread" : { "threadKey": "THREAD-'$(date +%s)'"}}' >> /dev/null
#################
chat_notification () 
{

# Simulate some work
sleep 2
######################################

if [ $ENVIRONMENT = "STAG" ]; then
    echo "STAG Environment"
    CDN='gcp'
chat_notification 

elif [ $ENVIRONMENT = "UAT" ]; then
    echo "UAT Environment"
    CDN='gcp-aws'
    chat_notification
else
    echo "ERROR: Invalid ENV_NAME"
    exit 1
fi
##################################

echo "Docker Deployment completed successfully"
apps-fileview.texmex_20260501.02_p0
Deployment_steps.txt
Displaying Deployment_steps.txt.
