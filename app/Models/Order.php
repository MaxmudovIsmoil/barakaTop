<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class Order extends Model
{
    use HasFactory;

//    protected $table = 'order';

    public $timestamps = false;

    protected $fillable = [
        'phone',
        'form',
        'to',
        'region_id',
        'region_id2',
        'client_id',
        'group_id',
        'status',
        'date_created',
        'date_accepted',
        'date_started',
        'date_closed',
        'driver_id',
        'department_id',
        'user_id',
        'arrival_time',
        'platform',
        'order_type',
        'counter1',
        'counter2',
        'distance',
        'distance_out',
        'sum',
        'sum_delivery',
        'bonus',
        'sum_bonus',
        'sum_services',
        'services',
        'comments',
        'latitude',
        'longitude',
        'ext1',
        'sum_offered',
        'user_id_delete',
        'user_id_modify',
        'flags',
        'rating_driver',
        'rating_service',
        'version',
        'partner_id',
        'parent_latitude',
        'parent_longitude',
    ];

    protected $attributes = [
        'region_id2'=> 0,
        'driver_id' => null,
        'latitude'  => null,
        'longitude' => null,
        'user_id_delete' => null,
        'user_id_modify' => null,
    ];


    public function partner()
    {
        return $this->hasOne(Partner::class, 'id', 'partner_id');
    }

    public function order_details()
    {
        return $this->hasMany(OrderDetails::class);
    }

    public function client()
    {
        return $this->hasOne(Client::class, 'id', 'client_id');
    }

    public function user()
    {
        return $this->hasOne(User::class, 'id', 'user_id');
    }

}
