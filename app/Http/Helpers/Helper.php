<?php

namespace App\Http\Helpers;


use App\Models\UserPriv;
use Illuminate\Support\Facades\Auth;

class Helper {

    /**
     * Phone number formatting.
     *
     * @param  string
     * @return string
     */
    public static function phoneFormat($phone)
    {
        if (mb_substr($phone, 0, 4) == '+998')
            $response = mb_substr($phone, 0, 4)." (".mb_substr($phone, 4, 2).") ".mb_substr($phone, 6, 3)."-".mb_substr($phone, 9, 2)."-".mb_substr($phone, -2);
        else
            $response = "(".mb_substr($phone, 0, 2).") ".mb_substr($phone, 2, 3)."-".mb_substr($phone, 5, 2)."-".mb_substr($phone, -2);

        return $response;

    }


    /**
     * Check user actions.
     *
     * @param int $action_id
     * @return bool
     */
    public static function checkUserActions($action_id = 0)
    {
        $user_id = Auth::user()->id;
        $action = UserPriv::where(['user_id' => $user_id, 'action_id' => $action_id])->first();
        if ($action)
            return true;

        return false;
    }



//    public static function sumFormat($sum)
//    {
//        return number_format($sum,2,", "," ");
//    }


}
