<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class OrderDetails extends Model
{
    use HasFactory;

    protected $table = 'order_details';

    public $timestamps = false;

    protected $fillable = [
        'order_id',
        'product_id',
        'quantity',
        'price',
        'additional',
    ];

    public function product()
    {
        return $this->hasOne(Product::class, 'id', 'product_id');
    }

}
