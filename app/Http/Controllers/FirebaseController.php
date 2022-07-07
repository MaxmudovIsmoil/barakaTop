<?php

namespace App\Http\Controllers;

use App\Models\User;
use Illuminate\Http\Request;

class FirebaseController extends Controller
{
    public function index()
    {
        return view('firebase.index');
    }

    public function savePushNotificationToken(Request $request)
    {
        auth()->user()->update(['device_token' => $request->token]);
        return response()->json(['token saved successfully.']);
    }

    public function sendPushNotificationTest(Request $request)
    {
        $firebaseToken = User::whereNotNull('device_token')->pluck('device_token')->all();

        $SERVER_API_KEY = 'AAAAS5_KXEQ:APA91bHpPfU0-KCNrV1oCK4l4d9P1ciJQqaBEiGopzXCTdwahAkSVqJlC5MSzCIYNYk_l2ClWdZfMb1tD3UPIBAMSHkHjbWrH2Mtg81BqxBLdso0bAxpzvI-BQIATJnM_pPXrdQu30CA';

        if ($request->event == 'accept_order')
            $msg = 'Buyurtmangiz tasdiqlandi';
        elseif ($request->event == 'book_order')
            $msg = "Buyurtmangiz tayyorlanyapti";
        elseif ($request->event == 'start_order')
            $msg = "Buyurtmangiz yo'lda";
        elseif ($request->event == 'close_order')
            $msg = "Buyurtmangiz yopildi";
        else if ($request->event == 'cancel_order')
            $msg = "Buyurtmangiz bekor qilindi";

        $data = [
            "registration_ids" => $firebaseToken,
            "notification" => [
               "title" => $request->title,
               'data'  => [
                   'event'  => $request->event,
                   'msg'    => $msg,
                   'title'  => 'Yangi xabar',
               ]
            ]
        ];
        $dataString = json_encode($data);

        $headers = [
            'Authorization: key=' . $SERVER_API_KEY,
            'Content-Type: application/json',
        ];

        $ch = curl_init();

        curl_setopt($ch, CURLOPT_URL, 'https://fcm.googleapis.com/fcm/send');
        curl_setopt($ch, CURLOPT_POST, true);
        curl_setopt($ch, CURLOPT_HTTPHEADER, $headers);
        curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, false);
        curl_setopt($ch, CURLOPT_SSL_VERIFYHOST, 0);
        curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
        curl_setopt($ch, CURLOPT_POSTFIELDS, $dataString);

        $response = curl_exec($ch);

        return response()->json($response);
//        dd($response);
//        curl_close($ch);
    }





    public static function sendPushNotification($client_token, $event, $msg)
    {
//        data={"event":"accept_order", "msg":"Buyurtmangiz tasdiqlandi", "title":"Yangi xabar"};
//        data={"event":"book_order", "msg":"Buyurtmangiz tayyorlanyapti", "title":"Yangi xabar"};
//        data={"event":"start_order", "msg":"Buyurtmangiz yo'lda", "title":"Yangi xabar"};
//        data={"event":"close_order", "msg":"Buyurtmangiz yopildi", "title":"Yangi xabar"};
//        data={"event":"cancel_order", "msg":"Buyurtmangiz bekor qilindi", "title":"Yangi xabar"};

//        $firebaseToken = User::whereNotNull('device_token')->pluck('device_token')->all();

        $SERVER_API_KEY = 'AAAAS5_KXEQ:APA91bHpPfU0-KCNrV1oCK4l4d9P1ciJQqaBEiGopzXCTdwahAkSVqJlC5MSzCIYNYk_l2ClWdZfMb1tD3UPIBAMSHkHjbWrH2Mtg81BqxBLdso0bAxpzvI-BQIATJnM_pPXrdQu30CA';


        $data = [
            "registration_ids" => $client_token,
            "notification" => [
                'data' => [
                    "event" => $event,
                    "msg"   => $msg,
                    "title" => "Yangi xabar",
                ]
            ]
        ];
        $dataString = json_encode($data);

        $headers = [
            'Authorization: key=' . $SERVER_API_KEY,
            'Content-Type: application/json',
        ];

        $ch = curl_init();

        curl_setopt($ch, CURLOPT_URL, 'https://fcm.googleapis.com/fcm/send');
        curl_setopt($ch, CURLOPT_POST, true);
        curl_setopt($ch, CURLOPT_HTTPHEADER, $headers);
        curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, false);
        curl_setopt($ch, CURLOPT_SSL_VERIFYHOST, 0);
        curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
        curl_setopt($ch, CURLOPT_POSTFIELDS, $dataString);

        $response = curl_exec($ch);
    }

}
