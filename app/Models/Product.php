<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class Product extends Model
{
    use HasFactory;

    //protected $table = 'products';

    public $timestamps = false;

    protected $fillable = [
        'name',
        'price',
        'image',
        'partner_id',
        'group',
        'parent_id',
        'type',
        'comments',
        'active',
        'date_created',
        'options',
        'ranting',
        'status',
        'discount',
    ];

    public function partner()
    {
        return $this->hasOne(Partner::class, 'id', 'partner_id');
    }


}
