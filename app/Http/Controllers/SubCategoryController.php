<?php

namespace App\Http\Controllers;

use App\Models\Partner;
use App\Models\Product;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Validator;

class SubCategoryController extends Controller
{
    /**
     * Display a listing of the resource.
     *
     * @return \Illuminate\Http\Response
     */
    public function index()
    {
        $partner = Partner::all();

        $products = Product::where(['parent_id' => 0])->orderBy('id', 'DESC')->paginate(50);


        return view('sub_category.index', compact('partner', 'products'));
    }


    public function get_sub_category($partner_id)
    {
        try {
            $sub_category = Product::where(['partner_id' => $partner_id, 'parent_id' => 0])->get();
            $count = $sub_category->count();

            return response()->json(['status' => true, 'sub_category' => $sub_category, 'count' => $count]);
        }
        catch (\Exception $exception) {
            return response()->json(['status' => false, 'errors' => $exception->getMessage()]);
        }
    }

    /**
     * Store a newly created resource in storage.
     *
     * @param  \Illuminate\Http\Request  $request
     * @return \Illuminate\Http\Response
     */
    public function store(Request $request)
    {
        $validation = Validator::make($request->all(), [
            'partner_id'=> 'required',
            'name'      => 'required',
            'images'    => 'required',
        ]);

        if ($validation->fails()) {
            return response()->json([
                'status' => false,
                'errors' => $validation->getMessageBag()->toArray()
            ]);
        }
        else {
            try {
                $image = $request->file('images')[0];
                $image_new_name = 'product_'.rand() .'.'.$image->getClientOriginalExtension();
                $image->move(public_path('images/'), $image_new_name);

                Product::create([
                    'name'      => $request->name,
                    'image'     => "images/".$image_new_name,
                    'partner_id'=> $request->partner_id,
                    'parent_id' => 0,
                    'price'     => 0,
                    'discount'  => 0,
                    'active'    => 1,
                    'comments'  => '',
                    'rating'    => 0,
                    'group'     => 0,
                    'type'      => 0,
                    'date_create'=> date('Y-m-d H:i:s'),
                    'options'   => null,
                    'status'    => 1,
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
            'partner_id'=> 'required',
            'name'      => 'required',
            'images'    => 'required',
        ];
    }

    public function show($id)
    {
        try {
            $product = Product::findOrFail($id);

            return response()->json(['status' => true, 'product' => $product]);
        }
        catch (\Exception $exception) {
            return response()->json(['status' => false, 'errors' => $exception->getMessage()]);
        }
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
                'partner_id'=> 'required',
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
                    'name'      => $request->name,
                    'partner_id'=> $request->partner_id,
                ];

                if ($request->file('images')) {

                    $image = $request->file('images')[0];
                    $image_new_name = 'product_'.rand() .'.'.$image->getClientOriginalExtension();
                    $image->move(public_path('images/'), $image_new_name);

                    array_push($update_data, ['image' => "images/".$image_new_name]);
                }

                $product = Product::findOrFail($id);
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

    /**
     * Remove the specified resource from storage.
     *
     * @param  int  $id
     * @return \Illuminate\Http\Response
     */
    public function destroy($id)
    {
        try {
            $u = Product::findOrFail($id);
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
