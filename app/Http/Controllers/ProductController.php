<?php

namespace App\Http\Controllers;

use App\Models\Partner;
use App\Models\Product;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Validator;
use Yajra\DataTables\DataTables;

class ProductController extends Controller
{

    public function index() {

        $products = Product::orderBy('id', 'DESC')->paginate(20);
        $products->load('partner');

        return view('product.index', compact( 'products'));
    }

    public function create() {

        $partners = Partner::all();
        $partner_id = $partners->first()->id;

        $parents = Product::where(['partner_id' => $partner_id, 'parent_id' => '0'])->get();

        return view('product.create', compact( 'partners', 'parents'));
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
                $image_new_name = 'product_'.rand() .'.'.$image->getClientOriginalExtension();
                $image->move(public_path('images/'), $image_new_name);


                Product::create([
                    'name'      => $request->name,
                    'image'     => "images/".$image_new_name,
                    'price'     => $request->price,
                    'partner_id'=> $request->partner_id,
                    'parent_id' => ($request->parent_id) ? $request->parent_id : 0,
                    'discount'  => ($request->discount) ? $request->discount : 0,
                    'active'    => $request->active,
                    'comments'  => ($request->comments) ? $request->comments : '',
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


    public function edit($id)
    {
        $partners = Partner::all();
        $partner_id = $partners->first()->id;

        $parents = Product::where(['partner_id' => $partner_id, 'parent_id' => '0'])->get();

        $product = Product::findOrFail($id);

        return view('product.edit', compact('partners', 'parents', 'product'));
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
                'price'     => 'required',
                'discount'  => 'required',
                'parent_id' => 'required',
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
                if ($request->file('images')) {

                    $image = $request->file('images')[0];
                    $image_new_name = 'product_'.rand() .'.'.$image->getClientOriginalExtension();
                    $image->move(public_path('images/'), $image_new_name);

                    $data = [
                            'name'      => $request->name,
                            'image'     => "images/".$image_new_name,
                            'price'     => $request->price,
                            'partner_id'=> $request->partner_id,
                            'parent_id' => ($request->parent_id) ? $request->parent_id : 0,
                            'discount'  => ($request->discount) ? $request->discount : 0,
                            'active'    => $request->active,
                            'comments'  => ($request->comments) ? $request->comments : '',
                            'date_create'=> date('Y-m-d H:i:s'),
                    ];
                }
                else {
                    $data = [
                            'name'      => $request->name,
                            'price'     => $request->price,
                            'partner_id'=> $request->partner_id,
                            'parent_id' => ($request->parent_id) ? $request->parent_id : 0,
                            'discount'  => ($request->discount) ? $request->discount : 0,
                            'active'    => $request->active,
                            'comments'  => ($request->comments) ? $request->comments : '',
                            'date_create'=> date('Y-m-d H:i:s'),
                    ];
                }

                $product = Product::findOrFail($id);
                $product->fill($data);
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

    public function store_validate()
    {
        return [
            'name'      => 'required',
            'images'    => 'required',
            'price'     => 'required',
            'partner_id'=> 'required',
            'discount'  => 'required',
        ];
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

            if ($exception->getCode() == 23000) {
                return response()->json(['status' => false, 'errors' => 'Ma\'lumotdan foydalanilyapti o\'chirish mumkin emas']);
            }

            return response()->json([
                'status' => false,
                'errors' => $exception->getMessage()
            ]);
        }

    }


}
