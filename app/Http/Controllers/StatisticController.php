<?php

namespace App\Http\Controllers;

use App\Models\Client;
use App\Models\Order;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Validator;
use Nette\Utils\DateTime;
use PHPUnit\Exception;

class StatisticController extends Controller
{
    /**
     * Display a listing of the resource.
     *
     * @return \Illuminate\Http\Response
     */
    public function index()
    {
        $date = new DateTime('now');
        $start_date = date('Y-m-d'); // this day
        $end_date = $date->modify('next day')->format('Y-m-d');


        // orders
        $order_all = Order::count();
        $orders = DB::table('orders')
                ->select('status', DB::raw('count(status) as total'))
                ->whereBetween('date_closed', [$start_date, $end_date])
                ->groupBy('status')
                ->get();
        $order_tushgan = 0;
        $order_bajarilgan = 0;
        foreach($orders as $o) {
            $order_tushgan += $o->total;
            if ($o->status == 4)
                $order_bajarilgan = $o->total;
        }



        // clients
        $client_all = Client::count();
        $client_new = Client::whereBetween('date_created', [$start_date, $end_date])->count();
        $client_active = Order::select('client_id')
                ->whereBetween('date_closed', [$start_date, $end_date])
                ->groupBy('client_id')
                ->get();
        $client_active_count = 0;
        foreach($client_active as $ca) {
            $client_active_count++;
        }


        // summa
        $summa = Order::select('orders.id', DB::raw('SUM(od.price) as summa'))
                ->leftJoin('order_details as od', 'od.order_id', '=', 'orders.id')
                ->whereBetween('orders.date_created', [$start_date, $end_date])
                ->groupBy('orders.id')
                ->get();
        $sum = 0;
        foreach($summa as $s) {
            $sum += $s->summa;
        }
        $summa = number_format($sum,  0, ',', ' ');



        return view('statistic.index', compact(
    'order_all',
    'order_tushgan',
            'order_bajarilgan',
            'client_all',
            'client_active_count',
            'client_new',
            'summa',
        ));
    }

    /**
     * Bir kinlik buyurtmalar saot bo'yicha
     **/
    public function order_hours_data($start_date, $end_date)
    {
        $order_array = DB::table('orders')
            ->select(DB::raw('DATE_FORMAT(date_created, "%H") as soat'), DB::raw('count(*) as total'))
            ->whereBetween('date_closed', [$start_date, $end_date])
            ->groupBy('soat')
            ->get();


        $begin = new DateTime( $start_date );
        $end   = new DateTime( $end_date );
        $days = [];
        for($i = $begin; $i < $end; $i->modify('+1 hour')){
            $days[] = $i->format("H");
        }

        $data = [];
        foreach($days as $day) {
            $data[$day] = 0;
            foreach ($order_array as $arr) {
                if ($day == $arr->soat)
                    $data[$day] = $arr->total;
            }
        }
        return $data;
    }


    public function client_hours_data($start_date, $end_date)
    {
        $client_array = DB::table('client')
            ->select(DB::raw('DATE_FORMAT(date_created, "%H") as date'), DB::raw('count(*) as total'))
            ->whereBetween('date_created', [$start_date, $end_date])
            ->groupBy('date')
            ->get();

        $begin = new DateTime( $start_date );
        $end   = new DateTime( $end_date );
        $days = [];
        for($i = $begin; $i < $end; $i->modify('+1 hour')) {
            $days[] = $i->format("H");
        }

        $data = [];
        foreach($days as $day) {
            $data[$day] = 0;
            foreach ($client_array as $arr) {
                if ($day == $arr->soat)
                    $data[$day] = $arr->total;
            }
        }
        return $data;

    }


    public function get_order_and_client_data_for_diagram()
    {
        try {
            $date = new DateTime('now');
            $start_date = date('Y-m-d'); // this day
            $end_date = $date->modify('next day')->format('Y-m-d');

            $order = $this->order_hours_data($start_date, $end_date);
            $order_data = [];
            foreach($order as $o) {
                $order_data[] = $o;
            }

            $client = $this->client_hours_data($start_date, $end_date);
            $client_data = [];
            foreach($client as $c) {
                $client_data[] = $c;
            }

            return response()->json(['status'=> true, 'order_data' => $order_data, 'client_data' => $client_data]);
        }
        catch(\Exception $exception) {
            return response()->json(['status' => false, 'errors' => $exception->getMessage()]);
        }
    }

    public function getStatistic(Request $request)
    {
        $validation = Validator::make($request->all(), [
            'start_date'=> 'required',
            'end_date'  => 'required',
        ]);

        if ($validation->fails()) {
            return response()->json([
                'status' => false,
                'errors' => $validation->getMessageBag()->toArray()
            ]);
        }
        else {
            try {
                $start_date = date('Y-m-d', strtotime($request->start_date));
                $end_date = date('Y-m-d', strtotime('+1 day', strtotime($request->end_date)));



                $orders = DB::table('orders')
                    ->select('status', DB::raw('count(status) as total'))
                    ->whereBetween('date_closed', [$start_date, $end_date])
                    ->groupBy('status')
                    ->get();

                $order_tushgan = 0;
                $order_bajarilgan = 0;
                foreach($orders as $o) {
                    $order_tushgan += $o->total;
                    if ($o->status == 4)
                        $order_bajarilgan = $o->total;
                }


                // clients
                $client_new = Client::whereBetween('date_created', [$start_date, $end_date])->count();
                $client_active = Order::select('client_id')
                    ->whereBetween('date_closed', [$start_date, $end_date])
                    ->groupBy('client_id')
                    ->get();
                $client_active_count = 0;
                foreach($client_active as $ca) {
                    $client_active_count++;
                }



                $summa = Order::select('orders.id', DB::raw('SUM(od.price) as summa'))
                    ->leftJoin('order_details as od', 'od.order_id', '=', 'orders.id')
                    ->whereBetween('orders.date_created', [$start_date, $end_date])
                    ->groupBy('orders.id')
                    ->get();

                $sum = 0;
                foreach($summa as $s) {
                    $sum += $s->summa;
                }
                $summa = number_format($sum,  0, ',', ' ');



                // -------------- diagram --------------
                $days = $this->loop_date_day($start_date, $end_date);

                $order_array = DB::table('orders')
                    ->select(DB::raw('DATE_FORMAT(date_created, "%d/%m") as date'), DB::raw('count(*) as total'))
                    ->whereBetween('date_closed', ['2022-03-04', $end_date])
                    ->groupBy('date')
                    ->get();

                $client_array = DB::table('client')
                    ->select(DB::raw('DATE_FORMAT(date_created, "%d/%m") as date'), DB::raw('count(*) as total'))
                    ->whereBetween('date_created', ['2022-03-04', $end_date])
                    ->groupBy('date')
                    ->get();

                $order_data = $this->data($start_date, $end_date, $order_array);
                $client_data = $this->data($start_date, $end_date, $client_array);


                $result = [
                    'order_tushgan'   => $order_tushgan,
                    'order_bajarilgan'=> $order_bajarilgan,
                    'client_active_count' => $client_active_count,
                    'client_new' => $client_new,
                    'summa' => $summa,
                    'days'  => $days,
                    'order_data'    => $order_data,
                    'client_data'   => $client_data,
                ];

                return response()->json(['status' => true, 'result' => $result]);
            }
            catch (\Exception $exception) {
                return view('statistic.index')->width(['error' => $exception->getMessage()]);
            }
        }
    }




    /**
     * days
     **/
    public function loop_date_day($start_date, $end_date) {
        $begin = new DateTime( $start_date );
        $end   = new DateTime( $end_date );
        $days = [];
        for($i = $begin; $i <= $end; $i->modify('+1 day')){
            $days[] = $i->format("d/m");
        }
        return $days;
    }

    /**
     * order and client data
     **/
    public function data($start_date, $end_date, $array)
    {
        $days = $this->loop_date_day($start_date, $end_date);

        $data = [];
        foreach($days as $day) {
            $data[] = 0;

            foreach ($array as $arr) {
                if ($day == $arr->date)
                    $data[] = $arr->total;
            }
        }

        return $data;
    }


}
