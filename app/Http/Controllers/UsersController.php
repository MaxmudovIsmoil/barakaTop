<?php

namespace App\Http\Controllers;


use App\Models\ActionModal;
use App\Models\User;
use App\Models\UserPriv;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Validator;


class UsersController extends Controller
{

    public function index()
    {
        $action = ActionModal::all();

        $users = User::orderByDesc('id')->get();

        return view('users.index', compact('action', 'users'));
    }



    public function oneUser($id)
    {
        try {
            $user = User::findOrFail($id);
            $user->load('user_priv');
            return response()->json(['status' => true, 'user' => $user]);
        }
        catch (\Exception $exception) {
            return response()->json(['status' => false, 'errors' => $exception->getMessage()]);
        }
    }


    public function store(Request $request)
    {
        $error = Validator::make($request->all(), $this->validateData());

        if ($error->fails()) {
            return response()->json(array(
                'success' => false,
                'errors' => $error->getMessageBag()->toArray()
            ));
        }
        else {
            try {
                $phone = str_replace(' ', '', $request->phone);

                DB::transaction(function () use ($phone, $request) {
                    $user_id = User::insertGetId([
                        'name' => $request->name,
                        'phone' => $phone,
                        'status' => $request->status,
                        'username' => $request->username,
                        'password' => Hash::make($request->password),
                        'email' => $request->username . "@gmail.com",
                        'created_at' => date('Y-m-d H:i:s'),
                        'updated_at' => date('Y-m-d H:i:s'),
                    ]);

                    foreach ($request->action as $action) {
                        UserPriv::create([
                            'user_id' => $user_id,
                            'action_id' => $action
                        ]);
                    }
                });
                return response()->json(['status' => true, 'msg' => 'ok']);

            } catch (\Exception $exception) {
                return response()->json(['status' => false, 'errors' => $exception->getMessage()]);
            }
        }
    }


    public function update(Request $request, $id)
    {
        $validate = $this->validateData();
        if ($request->old_username == $request->username)
            unset($validate['username']);

        if (!$request->password)
            unset($validate['password']);

        $validation = Validator::make($request->all(), $validate);
        if ($validation->fails()) {
            return response()->json([
                'status' => false,
                'errors' => $validation->getMessageBag()->toArray()
            ]);
        }
        else {
            try {
                $phone = str_replace(' ', '', $request->phone);
                $update_data = [
                    'name'      => $request->name,
                    'phone'     => $phone,
                    'status'    => $request->status,
                    'username'  => $request->username,
                    'password'  => Hash::make($request->password),
                    'updated_at'=>  date('Y-m-d H:i:s'),
                ];
                if ($request->old_username == $request->username)
                    unset($update_data['username']);

                if (!$request->password)
                    unset($update_data['password']);

                DB::transaction(function () use ($id, $update_data, $request) {

                    UserPriv::where('user_id', $id)->delete();

                    foreach ($request->action as $action) {
                        UserPriv::create([
                            'user_id' => $id,
                            'action_id' => $action
                        ]);
                    }

                    $product = User::findOrFail($id);
                    $product->fill($update_data);
                    $product->save();

                });
                return response()->json(['status' => true, 'msg' => 'ok']);
            }
            catch (\Exception $exception) {
                return response()->json(['status' => false, 'errors' => $exception->getMessage()]);
            }
        }
    }

    public function validateData()
    {
        return [
            'name'      => 'required',
            'phone'     => 'required',
            'username'  => 'required|unique:users,username',
            'password'  => 'required|min:6',
            'action'    => 'required',
        ];
    }

    public function destroy($id)
    {
        try {
            DB::transaction(function () use ($id) {
                $u = User::findOrFail($id);
                $u->delete();

                UserPriv::where('user_id', $id)->delete();
            });
            return response()->json(['status' => true, 'id' => $id]);
        }
        catch (\Exception $exception) {

            if ($exception->getCode() == 23000) {
                return response()->json(['status' => false, 'errors' => 'Ma\'lumotdan foydalanilyapti o\'chirish mumkin emas']);
            }

            return response()->json([
                'status' => false,
                'errors' => $exception->getMessage()
            ]);
        }
    }


    // user profile

    public function user_profile_show()
    {
        $user_id = Auth::user()->id;
        $user = User::findOrFail($user_id);
        $user->load('user_priv');

        $actions = ActionModal::all();
        return view('user_profile.index', compact('user', 'actions'));
    }

    public function user_profile_update(Request $request, $id)
    {
        $validation = Validator::make($request->all(), [
            'name'      => 'required',
            'phone'     => 'required',
            'username'  => 'required',
            'password'  => 'required|min:6',
        ]);
        if ($validation->fails()) {
            return response()->json([
                'status' => false,
                'errors' => $validation->getMessageBag()->toArray()
            ]);
        }
        else {
            try {
                $phone = str_replace(' ', '', $request->phone);
                $update_data = [
                    'name'      => $request->name,
                    'phone'     => $phone,
                    'password'  => Hash::make($request->password),
                    'updated_at'=>  date('Y-m-d H:i:s'),
                ];

                $product = User::findOrFail($id);
                $product->fill($update_data);
                $product->save();

                return response()->json(['status' => true, 'msg' => 'ok']);
            }
            catch (\Exception $exception) {
                return response()->json(['status' => false, 'errors' => $exception->getMessage()]);
            }
        }
    }
}
