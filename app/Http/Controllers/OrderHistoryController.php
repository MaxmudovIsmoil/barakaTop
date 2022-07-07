<?php

namespace App\Http\Controllers;

use App\Models\Order;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Validator;
use Nette\Utils\DateTime;

class OrderHistoryController extends Controller
{

    public function index()
    {
        return view('order_history.index');
    }

    public function getOrderHistory(Request $request) {

        $validation = Validator::make($request->all(), [
            'date_start'    => 'required',
            'date_end'      => 'required',
            'order_status'  => 'required',
        ]);

        if ($validation->fails()) {
            return response()->json([
                'status' => false,
                'errors' => $validation->getMessageBag()->toArray()
            ]);
        }
        else {
            $date_start = date('Y-m-d', strtotime($request->date_start));
            $date = new DateTime($request->date_end);
            $date_end = $date->modify('next day')->format('Y-m-d');

            $status = $request->order_status;

            $order_history = Order::where('status', $status)
                ->where('date_closed', '>=', $date_start)
                ->where('date_closed', '<=', $date_end)
                ->get();

            $order_history->load('partner', 'user', 'order_details');

            $date_start = $request->date_start;
            $date_end   = $request->date_end;

            return view('order_history.index', compact("order_history", 'date_start', 'date_end', 'status'));
        }
    }

    public function destroy($id)
    {
        try {
            $u = Order::findOrFail($id);
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
