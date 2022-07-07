<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class SMS extends Model
{
    use HasFactory;

    protected $table = 'sms';

    public $timestamps = false;

    protected $fillable = [
        'type',
        'status',
        'date',
        'order_id',
        'text',
        'phone',
        'code',
    ];

}
