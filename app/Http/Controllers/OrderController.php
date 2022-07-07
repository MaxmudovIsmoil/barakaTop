<?php

namespace App\Http\Controllers;

use App\Models\Client;
use App\Models\Order;
use App\Models\OrderDetails;
use App\Models\Partner;
use App\Models\Product;
use App\Models\SMS;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Validator;
use Yajra\DataTables\DataTables;

class OrderController extends Controller
{

    public function index()
    {
        $partner = Partner::where('active', 1)->get();

        return view('order.index', compact('partner'));
    }

    public function getOrders($id)
    {
        $id = ($id) ? $id : 1;
        if ($id == 1)
            $orders = Order::whereIn('status', [-1, 0, 1, 2])->orderBy('status', 'ASC')->orderByDesc('date_created')->get();
        else if($id == 2)
            $orders = Order::where('status', 3)->orderBy('status', 'ASC')->orderByDesc('date_created')->get();
        else if($id == 3)
            $orders = Order::where('status', 4)->orderBy('status', 'ASC')->orderByDesc('date_created')->get();

        $orders->load('client', 'order_details');

        return DataTables::of($orders)
            ->addIndexColumn()
            ->addColumn('client_name', function($order) {
                if ($order->client)
                    return optional($order->client)->name;
                else
                    return 'Yangi mijoz';
            })
            ->editColumn('phone', function ($order) {
                return \Helper::phoneFormat($order->phone);
            })
            ->addColumn('summa', function($order) {
                $summa = 0;
                foreach ($order->order_details as $od) {
                    $summa += $od->price * $od->quantity;
                }
                return number_format($summa,0,". "," ");
            })
            ->addColumn('address', function($order) {
                return "<div>".$order->from." <i class='fas fa-long-arrow-alt-right'></i>
                            <span class='badge badge-light-info'>".$order->to."</span></div>";
            })
            ->editColumn('status', function($order) {
                $res = '';
                if ($order->status == 0)
                    $res = "<span class='badge badge-light-danger'>Yangi</span>";
                elseif ($order->status == 1)
                    $res = "<span class='badge badge-light-primary'>Olingan</span>";
                elseif($order->status == 2)
                    $res = "<span class='badge badge-light-warning'>Bajarilmoqda</span>";
                elseif ($order->status == 3)
                    $res = "<span class='badge badge-light-secondary'>Bekor qilingan</span>";
                elseif ($order->status == 4)
                    $res = "<span class='badge badge-light-success'>Tugatilgan</span>";
                elseif($order->status == -1)
                    $res = "<span class='badge badge-light-info'>Tasdiqlanmagan</span>";

                return $res;
            })
            ->editColumn('date_created', function($order) {
                return date('d.m.Y H:i', strtotime($order->date_created));
            })
            ->addColumn('action', function ($order) {
                $client = isset($order->client->name) ? optional($order->client)->name : 'Yangi mijoz';

                $btn = '<div class="d-flex justify-content-around">';
                if (in_array($order->status, [0, 1, 2, -1])) {
                    if ($order->status == 0)
                        $btn .= '<a href="javascript:void(0);" title="Qabul qilish"
                                data-status_update_url="'.route('order.status_update', [$order->id]).'"
                                data-status="1"
                                class="text-success js_qabul_qilish_btn"><i class="fas fa-check"></i></a>';
                    else
                        $btn .= '<a href="javascript:void(0);" class="text-success order-status-icon-clicked"
                                title="Qabul qilingan"><i class="fas fa-check-double"></i></a>';


                    if ($order->status == 1)
                        $btn .= '<a href="javascript:void(0);" title="Tayyor bo\'ldi"
                                class="text-warning js_tayyor_boldi_btn"
                                data-status_update_url="'.route('order.status_update', [$order->id]).'"
                                data-status="2"><i class="fas fa-shopping-bag"></i></a>';
                    else
                        $btn .= '<a href="javascript:void(0);" class="text-warning order-status-icon-clicked"
                                    title="Tayyor bo\'ldi"><i class="fab fa-shopify"></i></a>';

                    if(\Helper::checkUserActions(204)) {
                        if ($order->status == 2)
                            $btn .= '<a href="javascript:void(0);" class="text-info js_yopish_btn"
                                        data-status_update_url="' . route('order.status_update', [$order->id]) . '"
                                        data-status="4" title="Buyurtmani yopish">
                                        <i class="fas fa-share"></i></a>';
                        else
                            $btn .= '<a href="javascript:void(0);" class="text-info order-status-icon-clicked" title="Buyurtmani yopish">
                                        <i class="fas fa-share"></i></a>';
                    }
                    else {
                        $btn .= '<a href="javascript:void(0);" class="text-secondary"
                                title="Ruxsat yo\'q"><i class="fas fa-share"></i></a>';
                    }

                        $btn .= '<a href="javascript:void(0);" class="text-danger"
                                data-toggle="modal" data-target="#order_close_modal_' . $order->id . '"
                                title="Bekor qilish">
                                <i class="fas fa-window-close"></i>
                            </a>
                            <!-- Buyurtmani bekor qilish modal -->
                            <div class="modal fade modal-danger text-left" id="order_close_modal_' . $order->id . '" tabindex="-1" data-backdrop="static">
                                <div class="modal-dialog modal-dialog-centered" role="document">
                                    <div class="modal-content">
                                        <div class="modal-header">
                                            <h5 class="modal-title">Buyurtmani bekor qilish</h5>
                                            <button type="button" class="close" data-dismiss="modal" aria-label="Close">
                                                <span aria-hidden="true">&times;</span>
                                            </button>
                                        </div>
                                        <div class="modal-body">
                                            <p class="d-flex justify-content-between"><span>' . $client . '</span><span>' . \Helper::phoneFormat($order->phone) . '</span></p>
                                            <textarea name="comment" class="form-control mt-1 js_comment" rows="2" placeholder="Izoh"></textarea>
                                        </div>
                                        <div class="modal-footer">
                                            <form action="' . route('order.status_update', [$order->id]) . '" class="js_order_close_form" method="POST">
                                                <input type="hidden" name="_token" value="' . csrf_token() . '" />
                                                <input type="hidden" name="status" class="js_status" value="3" />
                                                <input type="submit" value="Xa" class="btn btn-danger">
                                            </form>
                                            <button type="button" class="btn btn-secondary" data-dismiss="modal">Yo\'q</button>
                                        </div>
                                    </div>
                                </div>
                            </div>';

                    if(\Helper::checkUserActions(201)) {
                        $btn .= '<a href="javascript:void(0);" class="text-primary js_edit_btn"
                                    data-update_url="' . route('order.update', [$order->id]) . '"
                                    data-one_data_url="' . route('order.oneOrder', [$order->id]) . '"
                                    title="Tahrirlash">
                                    <i class="fas fa-pen"></i>
                                  </a>';
                    }
                    else {
                        $btn .= '<a href="javascript:void(0);" class="text-secondary" title="Ruxsat yo\'q">
                                    <i class="fas fa-pen"></i>
                                </a>';
                    }
                }


                if ($order->status == 3 || $order->status == 4) {
                    $btn .= '<a href="javascript:void(0);" class="text-info"
                               data-toggle="modal"
                               data-target="#order_details_modal_' . $order->id . '"
                               title="Malumot">
                               <i class="fas fa-eye"></i>
                            </a>';

                    $btn .= '<div class="modal fade modal-danger text-left" id="order_details_modal_' . $order->id . '" tabindex="-1" data-backdrop="static">
                                    <div class="modal-dialog modal-lg modal-dialog-centered" role="document">
                                        <div class="modal-content">
                                            <div class="modal-header">
                                                <h5 class="modal-title">' . $client . ' ' . \Helper::phoneFormat($order->phone) . '</h5>
                                                <button type="button" class="close" data-dismiss="modal" aria-label="Close">
                                                    <span aria-hidden="true">&times;</span>
                                                </button>
                                            </div>
                                            <div class="modal-body p-0">
                                                <table class="table table-striped">
                                                    <thead>
                                                        <th>№</th>
                                                        <th>Maxulot nomi</th>
                                                        <th>Miqdori</th>
                                                        <th>Narxi</th>
                                                    </thead>
                                                    <tbody>';
                                    $i = 1; $summa = 0;
                                    foreach ($order->order_details as $od) :
                                        $btn .= '<tr>
                                                    <td>' . ($i++) . '</td>
                                                    <td>' . $od->product->name . '</td>
                                                    <td>' . $od->quantity . '</td>
                                                    <td>' . number_format($od->price, 0, ". ", " ") . '</td>
                                                </tr>';
                                        $summa += $od->quantity * $od->price;
                                    endforeach;
                                        $btn .= '</tbody>
                                                </table>
                                            </div>
                                            <div class="modal-footer">
                                                <p class="mr-2 mb-0">Jami: '.number_format($summa,0,". "," ").'</p>
                                                <button type="button" class="btn btn-secondary" data-dismiss="modal">Yopish</button>
                                            </div>
                                        </div>
                                    </div>
                                </div>';
                }
                    if ($order->status == 3 || $order->status == 4) {
                        if(\Helper::checkUserActions(510)) {
                            $btn .= '<a href="javascript:void(0);" class="text-danger js_delete_btn"
                                    title="O\'chirish"
                                    data-toggle="modal"
                                    data-target="#deleteModal"
                                    data-name="' . $order->phone . '"
                                    data-url="' . route('order.destroy', [$order->id]) . '">
                                    <i class="fas fa-trash-alt"></i>
                                </a>';
                        }
                        else {
                            $btn .= '<a href="javascript:void(0);" class="text-secondary"
                                        title="Ruxsat yo\'q"><i class="fas fa-trash-alt"></i>
                                    </a>';
                        }
                    }
                    $btn .= '</div>';
                return $btn;
            })
            ->editColumn('id', '{{$id}}')
            ->rawColumns(['action', 'client_name', 'summa', 'address', 'status'])
            ->setRowClass('js_this_tr')
            ->setRowAttr(['data-id' => '{{ $id }}'])
            ->make(true);
    }


    public function oneOrder($id) {
        try {
            $order = Order::findOrFail($id);
            $order_details = OrderDetails::where(['order_id' => $id])->get();
            $order_details->load('product');
            return response()->json(['status' => true, 'order' => $order, 'order_details' => $order_details]);
        }
        catch (\Exception $exception) {
            return response()->json(['status' => false, 'errors' => $exception->getMessage()]);
        }
    }


    public function getProduct($partner_id, $parent_id)
    {
        try {
            if ($partner_id != 0)
                $where = ['partner_id' => $partner_id, 'parent_id' => $parent_id];
            else
                $where = ['partner_id' => $partner_id];

            $product = Product::where($where)
                ->orderByDesc('id')
                ->take(20)
                ->get();

            return response()->json(['status' => true, 'product' => $product]);
        }
        catch (\Exception $exception) {
            return response()->json(['status' => false, 'errors' => $exception->getMessage()]);
        }
    }


    public function getProductSearch(Request $request)
    {
        try {
            if ($request->parent_id != 0)
                $where = ['partner_id' => $request->partner_id, 'parent_id' => $request->parent_id];
            else
                $where = ['partner_id' => $request->partner_id];

            if ($request->name == '')
                $product = Product::whereRaw('LOWER(`name`) like ?', ['%'.strtolower($request->name).'%'])
                    ->orderByDesc('id')
                    ->get();
            else
                $product = Product::where($where)
                    ->whereRaw('LOWER(`name`) like ?', ['%'.strtolower($request->name).'%'])
                    ->orderByDesc('id')
                    ->get();

            return response()->json(['status' => true, 'product' => $product]);
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
        $validation = Validator::make($request->all(), $this->store_validate());

        if ($validation->fails()) {
            return response()->json([
                'status' => false,
                'errors' => $validation->getMessageBag()->toArray()
            ]);
        }
        else {
            try {
                $partner = Partner::findOrFail($request->partner_id);
                $summa = 0;
                for ($i = 0; $i < count($request->orders); $i++) {
                    $summa += $request->orders[$i]['price'] * $request->orders[$i]['quantity'];
                }
                $phone = str_replace(' ', '', $request->phone);

                DB::transaction(function () use ($partner, $summa, $phone, $request) {

                    $client = Client::where('phone', $phone)->first();
                    $client_id = null;
                    if(!$client) {
                        $client_id = Client::insertGetId([
                            'name' => $request->client_name,
                            'phone' => $phone,
                            'password' => 'password'
                        ]);
                    }

                    $order_id = Order::insertGetId([
                        'phone'     => $phone,
                        'from'      => $partner->name,
                        'to'        => $request->to,
                        'region_id' => $request->region_id,
                        'client_id' => isset($request->client_id) ? $request->client_id : $client_id,
                        'status'    => 1,
                        'date_created'  => date('Y-m-d H:i:s'),
                        'date_accepted' => date('Y-m-d H:i:s'),
                        'date_started'  => null,
                        'date_closed'   => null,
                        'user_id'       => Auth::user()->id,
                        'order_type'    => 4,
                        'sum'           => $summa,
                        'sum_delivery'  => $partner->sum_delivery,
                        'comments'      => '',
                        'partner_id'    => $partner->id,
                        'partner_latitude' => $partner->latitude,
                        'partner_longitude'=> $partner->longitude,
                    ]);

                    for ($i = 0; $i < count($request->orders); $i++) {
                    OrderDetails::create([
                        'order_id'  => $order_id,
                        'product_id'=> $request->orders[$i]['product_id'],
                        'price'     => $request->orders[$i]['price'],
                        'quantity'  => $request->orders[$i]['quantity'],
                        'additional'=> null,
                    ]);
                }

                });

                $firebase = FirebaseController::sendNotification('order', 'add');

                return response()->json(['status' => true, 'msg' => 'ok', 'firebase'=> $firebase]);
            } catch (\Exception $exception) {

                return response()->json([
                    'status' => false,
                    'errors' => $exception->getMessage()
                ]);
            }
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
        $validation = Validator::make($request->all(), $this->store_validate());
        if ($validation->fails()) {
            return response()->json([
                'status' => false,
                'errors' => $validation->getMessageBag()->toArray()
            ]);
        }
        else {
            try {
                $partner = Partner::findOrFail($request->partner_id);
                $summa = 0;
                for ($i = 0; $i < count($request->orders); $i++) {
                    $summa += $request->orders[$i]['price'] * $request->orders[$i]['quantity'];
                }

                DB::transaction(function () use ($partner, $summa, $id, $request) {

                    if ($request->old_phone != $request->phone) {
                        $client = Client::where('phone', $request->phone)->first();
                        if (!$client) {
                            $client_id = Client::insertGetId([
                                'name' => $request->client_name,
                                'phone' => $request->phone,
                                'password' => 'password'
                            ]);
                            $update_data = [
                                'phone' => $request->phone,
                                'from' => $partner->name,
                                'to' => $request->to,
                                'region_id' => $request->region_id,
                                'date_created' => date('Y-m-d H:i:s'),
                                'user_id' => Auth::user()->id,
                                'sum' => $summa,
                                'sum_delivery' => $partner->sum_delivery,
                                'partner_id' => $partner->id,
                                'partner_latitude' => $partner->latitude,
                                'partner_longitude' => $partner->longitude,
                                'client_id' => $client_id
                            ];
                        } else {
                            $update_data = [
                                'phone' => $request->phone,
                                'from' => $partner->name,
                                'to' => $request->to,
                                'region_id' => $request->region_id,
                                'date_created' => date('Y-m-d H:i:s'),
                                'user_id' => Auth::user()->id,
                                'sum' => $summa,
                                'sum_delivery' => $partner->sum_delivery,
                                'partner_id' => $partner->id,
                                'partner_latitude' => $partner->latitude,
                                'partner_longitude' => $partner->longitude,
                                'client_id' => $client->id
                            ];
                        }
                    } else {
                        $update_data = [
                            'phone' => $request->phone,
                            'from' => $partner->name,
                            'to' => $request->to,
                            'region_id' => $request->region_id,
                            'date_created' => date('Y-m-d H:i:s'),
                            'user_id' => Auth::user()->id,
                            'sum' => $summa,
                            'sum_delivery' => $partner->sum_delivery,
                            'partner_id' => $partner->id,
                            'partner_latitude' => $partner->latitude,
                            'partner_longitude' => $partner->longitude,
                        ];
                    }

                    if ($request->client_old_name != $request->client_name) {
                        Client::where('phone', $request->phone)->update(['name' => $request->client_name]);
                    }

                    $order = Order::findOrFail($id);
                    $order->fill($update_data);
                    $order->save();

                    $od = OrderDetails::where('order_id', $id);
                    $od->delete();

                    for ($i = 0; $i < count($request->orders); $i++) {
                        OrderDetails::create([
                            'order_id'  => $id,
                            'product_id'=> $request->orders[$i]['product_id'],
                            'price'     => $request->orders[$i]['price'],
                            'quantity'  => $request->orders[$i]['quantity'],
                            'additional'=> null,
                        ]);
                    }

                });

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
            'phone' => 'required',
            'to'    => 'required',
            'partner_id' => 'required',
            'orders' => 'required',
        ];
    }

    /**
     * Order status update.
     *
     * @param  \Illuminate\Http\Request  $request
     * @param  int  $id
     * @return \Illuminate\Http\Response
     */
    public function status_update(Request $request, $order_id)
    {
        try {
            $update_data = [];
            $msg = '';
            $now = date('Y-m-d H:i:s');
            if($request->status == 1) {
                // olingan
                $update_data = ['status' => $request->status, 'date_accepted' => $now];

                // firebase
                $event = "accept_order";
                $msg = "Buyurtmangiz tasdiqlandi";
            }
            else if ($request->status == 2) {
                // bajarilmoqda
                $update_data = ['status' => $request->status, 'date_started' => $now];

                // firebase
                $event = "book_order";
                $msg = "Buyurtmangiz tayyorlanyapti";
            }
            else if ($request->status == 3) {
                // bekor qilish
                $update_data = [
                    'status'     => $request->status,
                    'date_closed'=> $now,
                    'comments'   => isset($request->comment) ? $request->comment : ''
                ];

                // firebase
                $event = "cancel_order";
                $msg = "Buyurtmangiz bekor qilindi";
            }
            else if ($request->status == 4) {
                // yopilgan
                $update_data = ['status' => $request->status, 'date_closed' => $now];

                // firebase
                $event = "close_order";
                $msg = "Buyurtmangiz yopildi";
            }

            $order = Order::findOrFail($order_id);
            $order->update($update_data);

            $client = Client::findOrFail($order->client_id);

            if ($client->token !== null) {
                FirebaseController::sendPushNotification($client->token, $event, $msg);
            }
            else {
                // sms jadvaliga yozish kerak
                SMS::create([
                   'type'  => 5,
                    'status' => $request->status,
                    'date' => $now,
                    'order_id' => $order_id,
                    'text' => $msg,
                    'phone'=> $order->phone,
                    'code' => null
                ]);
            }

            return response()->json(['status' => true, 'order_id' => $order_id, 'msg' => 'ok']);
        }
        catch(\Exception $exception) {
            return response()->json(['status' => false, 'errors' => $exception->getMessage()]);
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
            DB::transaction(function () use ($id) {
                $u = Order::findOrFail($id);
                $u->delete();

                $od = OrderDetails::where('order_id', $id);
                $od->delete();
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




    // client name
    public function get_client_name(Request $request)
    {
        try {
            $client = Client::where('phone', 'LIKE', '%'.$request->phone)->first();

            return response()->json(['status' => true, 'client' => $client]);
        }
        catch (\Exception $exception) {
            return response()->json(['status' => false, 'errors' => $exception->getMessage()]);
        }
    }

}
