<?php

namespace App\Http\Controllers;

use App\Models\Partner;
use App\Models\PartnerGroup;
use App\Models\Region;
use Illuminate\Http\Request;
use App\Http\Helpers;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Validator;


class PartnerController extends Controller
{
    /**
     * Display a listing of the resource.
     *
     * @return \Illuminate\Http\Response
     */
    public function index()
    {
        $partners = Partner::orderBy('id','DESC')->paginate(20);
        $partners->load('partner_group', 'region');

        return view('partner.index', compact('partners'));
    }

    /**
     * Show the form for creating a new resource.
     *
     * @return \Illuminate\Http\Response
     */
    public function create()
    {
        $partner_group = PartnerGroup::all();

        $region = Region::all();

        return view('partner.create', compact('partner_group', 'region'));
    }

    /**
     * Store a newly created resource in storage.
     *
     * @param  \Illuminate\Http\Request  $request
     * @return \Illuminate\Http\Response
     */
    public function store(Request $request)
    {
        $validation = Validator::make($request->all(), $this->store_validate());

        if ($validation->fails()) {
            return response()->json([
                'status' => false,
                'errors' => $validation->getMessageBag()->toArray()
            ]);
        }
        else {
            try {
                $image = $request->file('images')[0];
                $image_name = 'partner_'.rand() .'.'.$image->getClientOriginalExtension();
                $image->move(public_path('images/'), $image_name);


                $background_image = $request->file('background_image')[0];
                $background_image_name = 'partner_'.rand() .'.'.$image->getClientOriginalExtension();
                $background_image->move(public_path('images/'), $background_image_name);


                Partner::create([
                    'group_id'  => $request->group_id,
                    'region_id' => $request->region_id,
                    'name'      => $request->name,
                    'image'     => "images/".$image_name,
                    'phone'     => $request->phone,
                    'open_time' => date("H:i:s", strtotime($request->open_time)),
                    'close_time'=> date("H:i:s", strtotime($request->close_time)),
                    'active'    => $request->active,
                    'background'=> "images/".$background_image_name,
                    'comments'  => ($request->comments) ? $request->comments : '',
                    'rating'    => 0,
                    'login'     => $request->login,
                    'password'  => $request->password,
                    'price'     => 0,
                    'latitude' => null,
                    'longitude' => null,
                    'closed'    => $request->closed,
                    'date_create'=> date('Y-m-d H:i:s'),
                    'sum_min'   => $request->sum_min,
                    'sum_delivery'=> $request->sum_delivery,
                    'user_group'=> Auth::user()->id,
                ]);

                return response()->json(['status' => true, 'msg' => 'ok']);
            } catch (\Exception $exception) {

                return response()->json([
                    'status' => false,
                    'errors' => $exception->getMessage()
                ]);
            }
        }
    }

    public function store_validate()
    {
        return [
            'login'     => 'required|unique:partner',
            'password'  => 'required|min:3',
            'group_id'  => 'required',
            'region_id' => 'required',
            'name'      => 'required',
            'images'    => 'required',
            'background_image' => 'required',
            'phone'  => 'required',
            'open_time' => 'required',
            'close_time'=> 'required',
            'sum_min'   => 'required',
            'sum_delivery' => 'required',
        ];
    }


    /**
     * Show the form for editing the specified resource.
     *
     * @param  int  $id
     * @return \Illuminate\Http\Response
     */
    public function edit($id)
    {
        $partner_group = PartnerGroup::all();
        $region = Region::all();

        $partner = Partner::findOrFail($id);

        return view('partner.edit', compact('partner_group', 'region', 'partner'));
    }

    /**
     * Update the specified resource in storage.
     *
     * @param  \Illuminate\Http\Request  $request
     * @param  int  $id
     * @return \Illuminate\Http\Response
     */
    public function update(Request $request, $id)
    {
        if ($request->file('images'))
            $validate = $this->store_validate();
        else
            $validate = [
                'name'      => 'required',
                'phone'     => 'required',
                'open_time' => 'required',
                'close_time'=> 'required',
                'sum_min'   => 'required',
                'sum_delivery' => 'required',
            ];


        $validation = Validator::make($request->all(), $validate);
        if ($validation->fails()) {
            return response()->json([
                'status' => false,
                'errors' => $validation->getMessageBag()->toArray()
            ]);
        }
        else {
            try {

                $update_data = [
                    'group_id'  => $request->group_id,
                    'region_id' => $request->region_id,
                    'name'      => $request->name,
                    'phone'     => $request->phone,
                    'open_time' => date("H:i:s", strtotime($request->open_time)),
                    'close_time'=> date("H:i:s", strtotime($request->close_time)),
                    'active'    => $request->active,
                    'comments'  => ($request->comments) ? $request->comments : '',
                    'login'     => $request->login,
                    'password'  => $request->password,
                    'closed'    => $request->closed,
                    'sum_min'   => $request->sum_min,
                    'sum_delivery'=> $request->sum_delivery,
                    'user_group'=> Auth::user()->id,
                ];

                if ($request->file('images') && $request->file('background')) {

                    $image = $request->file('images')[0];
                    $image_name = 'partner_'.rand() .'.'.$image->getClientOriginalExtension();
                    $image->move(public_path('images/'), $image_name);

                    $background_image = $request->file('background')[0];
                    $background_image_name = 'partner_'.rand() .'.'.$background_image->getClientOriginalExtension();
                    $background_image->move(public_path('images/'), $background_image_name);

                    array_push($update_data, [
                            'image' => "images/".$image_name,
                            'background'=> "images/".$background_image_name,
                        ]
                    );
                }
                else if($request->file('images')) {

                    $image = $request->file('images')[0];
                    $image_name = 'partner_'.rand() .'.'.$image->getClientOriginalExtension();
                    $image->move(public_path('images/'), $image_name);

                    array_push($update_data, [ 'image' => "images/".$image_name] );
                }
                else if ($request->file('background')) {

                    $background_image = $request->file('background')[0];
                    $background_image_name = 'partner_'.rand() .'.'.$background_image->getClientOriginalExtension();
                    $background_image->move(public_path('images/'), $background_image_name);

                    array_push($update_data, [ 'background'=> "images/".$background_image_name ]);
                }

                if (!$request->password)
                    unset($update_data['password']);

                $product = Partner::findOrFail($id);
                $product->fill($update_data);
                $product->save();

                return response()->json(['status' => true, 'msg' => 'ok']);
            }
            catch (\Exception $exception) {
                return response()->json([
                    'status' => false,
                    'errors' => $exception->getMessage()
                ]);
            }
        }
    }


    public function open_close(Request $request)
    {
        try {
            $partner = Partner::findOrFail($request->partner_id);
            $partner->fill(['active' => $request->active]);
            $partner->save();

            return response()->json(['status' => true, 'msg' => 'ok']);
        }
        catch(\Exception $exception) {
            return response()->json(['status' => false, 'errors'=>$exception->getMessage()]);
        }
    }

    /**
     * Remove the specified resource from storage.
     *
     * @param  int  $id
     * @return \Illuminate\Http\Response
     */
    public function destroy($id)
    {
        try {
            $u = Partner::findOrFail($id);
            $u->delete();
            return response()->json(['status' => true, 'id' => $id]);
        }
        catch (\Exception $exception) {

            return response()->json([
                'status' => false,
                'errors' => $exception->getMessage()
            ]);
        }
    }
}
