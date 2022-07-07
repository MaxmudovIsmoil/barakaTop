<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class Partner extends Model
{
    use HasFactory;

    protected $table = 'partner';

    public $timestamps = false;

    protected $fillable = [
        'name',
        'image',
        'login',
        'password',
        'region_id',
        'phone',
        'active',
        'background',
        'group_id',
        'comments',
        'open_time',
        'close_time',
        'rating',
        'price',
        'closed',
        'user_group',
        'latitude',
        'longitude',
        'sum_min',
        'sum_delivery',
    ];

    public function partner_group()
    {
        return $this->hasOne(PartnerGroup::class, 'id', 'group_id');
    }

    public function region()
    {
        return $this->hasOne(Region::class, 'id', 'region_id');
    }
}
